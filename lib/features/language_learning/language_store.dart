import "package:drift/drift.dart";
import "package:uuid/uuid.dart";

import "../../core/database/database.dart";
import "../../core/database/database_notifier.dart";
import "../../core/l10n/app_error.dart";
import "fsrs.dart";
import "lexical_form.dart";
import "generation_store.dart";
import "vocabulary_review_settings.dart";

export "fsrs.dart" show RecallRating;

const languageBatchSize = 20;
String normalizeLanguageText(String value) =>
    value.trim().replaceAll(RegExp(r"\s+"), " ").toLowerCase();

enum LexicalType { word, phrase, phrasalVerb, collocation, idiom }

enum VocabularyGroupType { topic, concept, function, contrast }

enum RecallKind { scheduled, retry, practice }

const _wordInTrash = AppFormatException(
  AppErrorCode.languageWordInTrash,
  "Vocabulary is in the trash",
);

class VocabularyEntry {
  const VocabularyEntry({
    required this.form,
    required this.meaning,
    this.type = LexicalType.word,
    this.partOfSpeech,
    this.example,
    this.translation,
    this.application,
    this.applicationAnswer,
    this.forms = const [],
  });

  final String form, meaning;
  final LexicalType type;
  final List<LexicalFormDraft> forms;
  final String? partOfSpeech,
      example,
      translation,
      application,
      applicationAnswer;

  (String, String, String) get _key =>
      (normalizeLanguageText(form), type.name, meaning.trim());
}

class VocabularyProvenance {
  const VocabularyProvenance({
    required this.batchId,
    required this.model,
    required this.promptVersion,
    required this.generatedAt,
    required this.mock,
    this.generationIds = const [],
    this.generationByForm = const {},
  });

  final String batchId, model;
  final List<String> generationIds;
  final Map<String, String> generationByForm;
  final int promptVersion;
  final DateTime generatedAt;
  final bool mock;
}

class LanguageCard {
  const LanguageCard(this.item, this.sense, {this.isNew = false});

  final LearningLexicalItem item;
  final LearningLexicalSense sense;
  final bool isNew;
}

class LanguageLearningStore extends DatabaseNotifier {
  LanguageLearningStore(this.db);
  final AppDatabase db;
  static const _uuid = Uuid();

  Future<LearningVocabularyGroup?> groupNamed(
    String language,
    String title,
  ) async {
    final normalized = normalizeLanguageText(title);
    final rows = await (db.select(
      db.learningVocabularyGroups,
    )..where((g) => g.language.equals(language))).get();
    return rows
        .where((g) => normalizeLanguageText(g.title) == normalized)
        .firstOrNull;
  }

  Future<String> createGroup(
    String language,
    String title,
    VocabularyGroupType type,
  ) => runOperation(() async {
    if (title.trim().isEmpty) throw ArgumentError("A group name is required");
    final id = _uuid.v4();
    await db.transaction(() async {
      if (await groupNamed(language, title) != null) {
        throw ArgumentError("A group with this name already exists");
      }
      await db
          .into(db.learningVocabularyGroups)
          .insert(
            LearningVocabularyGroupsCompanion.insert(
              id: id,
              language: language,
              title: title.trim(),
              groupType: Value(type.name),
              createdAt: DateTime.now(),
            ),
          );
    });
    changed();
    return id;
  });

  Future<List<String>> groupExpressions(String groupId) async {
    final rows = await db
        .customSelect(
          "SELECT DISTINCT i.form FROM learning_group_items g JOIN learning_lexical_senses s ON s.id = g.sense_id JOIN learning_lexical_items i ON i.id = s.item_id WHERE g.group_id = ? AND s.deleted_at IS NULL",
          variables: [Variable(groupId)],
          readsFrom: {
            db.learningGroupItems,
            db.learningLexicalSenses,
            db.learningLexicalItems,
          },
        )
        .get();
    return rows.map((r) => r.read<String>("form")).toList();
  }

  JoinedSelectStatement _trashed(String language) {
    final items = db.learningLexicalItems;
    final senses = db.learningLexicalSenses;
    return db.select(senses).join([
      innerJoin(items, items.id.equalsExp(senses.itemId)),
    ])..where(items.language.equals(language) & senses.deletedAt.isNotNull());
  }

  Stream<List<LanguageCard>> trashedCards(String language) =>
      (_trashed(language)..orderBy([
            OrderingTerm.desc(db.learningLexicalSenses.deletedAt),
            OrderingTerm.asc(db.learningLexicalItems.normalizedForm),
            OrderingTerm.asc(db.learningLexicalSenses.id),
          ]))
          .watch()
          .map(
            (rows) => [
              for (final row in rows)
                LanguageCard(
                  row.readTable(db.learningLexicalItems),
                  row.readTable(db.learningLexicalSenses),
                ),
            ],
          );

  Future<Set<String>> trashedExpressions(String language) async => {
    for (final row in await _trashed(language).get())
      row.readTable(db.learningLexicalItems).normalizedForm,
  };

  Future<void> moveToTrash(Iterable<String> senseIds) =>
      _setTrash(senseIds, DateTime.now());

  Future<void> restoreVocabulary(Iterable<String> senseIds) =>
      _setTrash(senseIds, null);

  Future<void> _setTrash(Iterable<String> senseIds, DateTime? deletedAt) =>
      runOperation(() async {
        await (db.update(db.learningLexicalSenses)..where(
              (s) =>
                  s.id.isIn(senseIds) &
                  (deletedAt == null
                      ? s.deletedAt.isNotNull()
                      : s.deletedAt.isNull()),
            ))
            .write(LearningLexicalSensesCompanion(deletedAt: Value(deletedAt)));
        changed();
      });

  Future<void> deleteTrashedVocabulary(Iterable<String> senseIds) =>
      runOperation(() async {
        await db.transaction(() async {
          final senses = db.learningLexicalSenses;
          final deleted =
              await (db.delete(senses)..where(
                    (s) => s.id.isIn(senseIds) & s.deletedAt.isNotNull(),
                  ))
                  .goAndReturn();
          if (deleted.isEmpty) return;
          await (db.delete(db.languageGenerationLinks)..where(
                (link) =>
                    link.kind.equals("vocabulary") &
                    link.contentId.isIn(deleted.map((s) => s.id)),
              ))
              .go();
          await (db.delete(db.learningLexicalItems)..where(
                (item) =>
                    item.id.isIn(deleted.map((s) => s.itemId)) &
                    existsQuery(
                      db.selectOnly(senses)
                        ..addColumns([senses.id])
                        ..where(senses.itemId.equalsExp(item.id)),
                    ).not(),
              ))
              .go();
        });
        changed();
      });

  Future<void> saveEntries({
    required String language,
    required String groupTitle,
    required VocabularyGroupType groupType,
    required List<VocabularyEntry> entries,
    VocabularyProvenance? provenance,
    String? quickLookupId,
    DateTime? now,
  }) => runOperation(() async {
    final time = now ?? DateTime.now();
    final title = groupTitle.trim();
    if (title.isEmpty ||
        entries.isEmpty ||
        entries.any(
          (entry) => entry.form.trim().isEmpty || entry.meaning.trim().isEmpty,
        )) {
      throw ArgumentError("A group title, expression and meaning are required");
    }
    await db.transaction(() async {
      if (provenance != null) {
        final trashed = await trashedExpressions(language);
        if (entries.any((entry) => trashed.contains(entry._key.$1))) {
          throw _wordInTrash;
        }
      }
      final existing = await groupNamed(language, title);
      final groupId = existing?.id ?? _uuid.v4();
      if (existing == null) {
        await db
            .into(db.learningVocabularyGroups)
            .insert(
              LearningVocabularyGroupsCompanion.insert(
                id: groupId,
                language: language,
                title: title,
                groupType: Value(groupType.name),
                createdAt: time,
              ),
            );
      }
      for (final entry in entries) {
        final senseId = await _saveEntry(
          language,
          groupId,
          entry,
          provenance,
          time,
        );
        if (quickLookupId != null) {
          await db
              .into(db.languageQuickLearningLinks)
              .insert(
                LanguageQuickLearningLinksCompanion.insert(
                  lookupId: quickLookupId,
                  senseId: Value(senseId),
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    });
    changed();
  });

  Future<void> reviseVocabulary(
    LanguageCard card,
    VocabularyEntry entry,
    LanguageGenerationRun run,
  ) => runOperation(
    () => db.transaction(() async {
      if (normalizeLanguageText(entry.form) != card.item.normalizedForm ||
          entry.type.name != card.item.lexicalType ||
          entry.meaning.trim() != card.sense.meaning) {
        throw ArgumentError("A revision must preserve the lexical sense");
      }
      final current = await (db.select(
        db.learningLexicalSenses,
      )..where((s) => s.id.equals(card.sense.id))).getSingle();
      if (current.deletedAt != null || current != card.sense) {
        throw StateError("Vocabulary changed while generating");
      }
      if (run.provider == null) {
        await LanguageGenerationStore(db)
            .link("vocabulary", card.sense.id, run.id);
        return;
      }
      await (db.update(
        db.learningLexicalSenses,
      )..where((s) => s.id.equals(card.sense.id))).write(
        LearningLexicalSensesCompanion(
          partOfSpeech: Value(entry.partOfSpeech),
          example: Value(entry.example),
          exampleTranslation: Value(entry.translation),
          application: Value(entry.application),
          applicationAnswer: Value(entry.applicationAnswer),
          source: const Value("ai"),
          aiBatchId: Value(run.id),
          aiModel: Value(run.model),
          aiPromptVersion: const Value(null),
          aiGeneratedAt: Value(run.createdAt),
        ),
      );
      await LanguageGenerationStore(db)
          .link("vocabulary", card.sense.id, run.id);
      changed();
    }),
  );

  Future<String> _saveEntry(
    String language,
    String groupId,
    VocabularyEntry entry,
    VocabularyProvenance? provenance,
    DateTime time,
  ) async {
    final normalized = normalizeLanguageText(entry.form);
    final item =
        await (db.select(db.learningLexicalItems)..where(
              (row) =>
                  row.language.equals(language) &
                  row.normalizedForm.equals(normalized) &
                  row.lexicalType.equals(entry.type.name),
            ))
            .getSingleOrNull();
    final itemId = item?.id ?? _uuid.v4();
    if (item == null) {
      await db
          .into(db.learningLexicalItems)
          .insert(
            LearningLexicalItemsCompanion.insert(
              id: itemId,
              language: language,
              form: entry.form.trim(),
              normalizedForm: normalized,
              lexicalType: Value(entry.type.name),
              createdAt: time,
            ),
          );
    }
    final meaning = entry.meaning.trim();
    final sense =
        await (db.select(db.learningLexicalSenses)..where(
              (row) => row.itemId.equals(itemId) & row.meaning.equals(meaning),
            ))
            .getSingleOrNull();
    final senseId = sense?.id ?? _uuid.v4();
    if (sense?.deletedAt != null) throw _wordInTrash;
    final partOfSpeech = _optional(entry.partOfSpeech);
    final application = _optional(entry.application);
    final answer = _optional(entry.applicationAnswer);
    if ((application != null || answer != null) &&
        (application == null ||
            answer == null ||
            "___".allMatches(application).length != 1)) {
      throw ArgumentError("An application requires one blank and an answer");
    }
    if (sense == null) {
      await db
          .into(db.learningLexicalSenses)
          .insert(
            LearningLexicalSensesCompanion.insert(
              id: senseId,
              itemId: itemId,
              meaning: meaning,
              partOfSpeech: Value(partOfSpeech),
              example: Value(_optional(entry.example)),
              exampleTranslation: Value(_optional(entry.translation)),
              application: Value(application),
              applicationAnswer: Value(answer),
              source: Value(switch (provenance) {
                null => "user",
                VocabularyProvenance(mock: true) => "mock",
                _ => "ai",
              }),
              aiBatchId: Value(provenance?.batchId),
              aiModel: Value(provenance?.model),
              aiPromptVersion: Value(provenance?.promptVersion),
              aiGeneratedAt: Value(provenance?.generatedAt),
              createdAt: time,
            ),
          );
      await db
          .into(db.learningReviewSchedules)
          .insert(
            LearningReviewSchedulesCompanion.insert(
              senseId: senseId,
              dueAt: time,
              updatedAt: time,
            ),
          );
    } else if (provenance == null) {
      // Adding a previously saved sense to a group can fill in missing material,
      // but must not overwrite another group's content or reset its review.
      final example = _optional(entry.example);
      final translation = _optional(entry.translation);
      final additions = LearningLexicalSensesCompanion(
        partOfSpeech: sense.partOfSpeech == null && partOfSpeech != null
            ? Value(partOfSpeech)
            : const Value.absent(),
        example: sense.example == null && example != null
            ? Value(example)
            : const Value.absent(),
        exampleTranslation:
            sense.exampleTranslation == null &&
                translation != null &&
                (sense.example == null || sense.example == example)
            ? Value(translation)
            : const Value.absent(),
        application: sense.application == null && application != null
            ? Value(application)
            : const Value.absent(),
        applicationAnswer: sense.application == null && answer != null
            ? Value(answer)
            : const Value.absent(),
      );
      if (additions.toColumns(false).isNotEmpty) {
        await (db.update(
          db.learningLexicalSenses,
        )..where((row) => row.id.equals(senseId))).write(additions);
      }
    }
    await db
        .into(db.learningGroupItems)
        .insert(
          LearningGroupItemsCompanion.insert(
            groupId: groupId,
            senseId: senseId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    for (final form in entry.forms) {
      await insertLexicalForm(db, senseId, entry.form, form);
    }
    await LanguageGenerationStore(db)
        .link("vocabulary", senseId, provenance?.generationByForm[normalized]);
    return senseId;
  }

  /// Matches forms across senses so rephrased definitions are still flagged.
  Future<Map<VocabularyEntry, List<String>>> existingGroupsForEntries(
    String language,
    List<VocabularyEntry> entries,
  ) async {
    if (entries.isEmpty) return {};
    final item = db.learningLexicalItems;
    final sense = db.learningLexicalSenses;
    final membership = db.learningGroupItems;
    final group = db.learningVocabularyGroups;
    final query =
        db.selectOnly(item).join([
            innerJoin(
              sense,
              sense.itemId.equalsExp(item.id),
              useColumns: false,
            ),
            innerJoin(
              membership,
              membership.senseId.equalsExp(sense.id),
              useColumns: false,
            ),
            innerJoin(
              group,
              group.id.equalsExp(membership.groupId),
              useColumns: false,
            ),
          ])
          ..addColumns([
            item.normalizedForm,
            item.lexicalType,
            sense.meaning,
            group.title,
          ])
          ..where(
            item.language.equals(language) &
                sense.deletedAt.isNull() &
                item.normalizedForm.isIn(entries.map((entry) => entry._key.$1)),
          )
          ..orderBy([OrderingTerm.asc(group.title)]);
    final matches = <(String, String), List<String>>{};
    for (final row in await query.get()) {
      final key = (row.read(item.normalizedForm)!, row.read(item.lexicalType)!);
      (matches[key] ??= []).add(row.read(group.title)!);
    }
    return {
      for (final entry in entries)
        entry: matches[(entry._key.$1, entry._key.$2)] ?? const [],
    };
  }

  Stream<List<LearningVocabularyGroup>> groups(String language) =>
      (db.select(db.learningVocabularyGroups)
            ..where((group) => group.language.equals(language))
            ..orderBy([(group) => OrderingTerm.asc(group.title)]))
          .watch();

  Future<void> deleteGroup(String id) => runOperation(() async {
    await (db.delete(
      db.learningVocabularyGroups,
    )..where((group) => group.id.equals(id))).go();
    changed();
  });

  Stream<int> dueCount(String language, {DateTime? now}) =>
      _dueCount(language, now).watchSingle();

  Future<int> countDue(String language, {DateTime? now}) =>
      _dueCount(language, now).getSingle();

  Selectable<int> _dueCount(String language, DateTime? now) {
    final count = db.learningLexicalSenses.id.count();
    final q = _queue(language, includeCards: false);
    q
      ..where(_isDue(now))
      ..addColumns([count]);
    return q.map((row) => row.read(count)!);
  }

  Expression<bool> _isDue(DateTime? now) {
    final review = db.learningReviewSchedules;
    return review.repetitions.isBiggerThanValue(0) &
        review.dueAt.isSmallerOrEqual(
          now == null ? currentDateAndTime : Variable(now),
        );
  }

  Future<List<LanguageCard>> cards({
    required String language,
    String? groupId,
    DateTime? dueBefore,
    bool contextsOnly = false,
    int offset = 0,
    int limit = languageBatchSize,
  }) async {
    final q =
        _queue(
            language,
            groupId: groupId,
            dueBefore: dueBefore,
            contextsOnly: contextsOnly,
          )
          ..orderBy([
            OrderingTerm.asc(
              dueBefore == null
                  ? db.learningLexicalSenses.createdAt
                  : db.learningReviewSchedules.dueAt,
            ),
            OrderingTerm.asc(db.learningLexicalSenses.id),
          ])
          ..limit(limit, offset: offset);
    return (await q.get())
        .map(
          (row) => LanguageCard(
            row.readTable(db.learningLexicalItems),
            row.readTable(db.learningLexicalSenses),
          ),
        )
        .toList();
  }

  Future<List<LanguageCard>> recallCards({
    required String language,
    required DateTime now,
    required int limit,
    String? groupId,
    bool allGroups = false,
    bool dueOnly = false,
    bool practiceOnly = false,
    Set<String> seen = const {},
  }) async {
    final sense = db.learningLexicalSenses;
    final review = db.learningReviewSchedules;
    final isNew = review.repetitions.equals(0);
    final q = _queue(language, groupId: groupId)..addColumns([isNew]);
    if (allGroups) {
      final membership = db.learningGroupItems;
      q.where(
        existsQuery(
          db.selectOnly(membership)
            ..addColumns([membership.senseId])
            ..where(membership.senseId.equalsExp(sense.id)),
        ),
      );
    }
    if (!practiceOnly) {
      q.where(dueOnly ? _isDue(now) : _isDue(now) | isNew);
    }
    if (seen.isNotEmpty) q.where(sense.id.isNotIn(seen));
    q
      ..orderBy([
        if (!practiceOnly) OrderingTerm.asc(isNew),
        OrderingTerm.asc(
          practiceOnly
              ? sense.createdAt
              : CaseWhenExpression(
                  cases: [CaseWhen(isNew, then: sense.createdAt)],
                  orElse: review.dueAt,
                ),
        ),
        OrderingTerm.asc(sense.id),
      ])
      ..limit(limit);
    return [
      for (final row in await q.get())
        LanguageCard(
          row.readTable(db.learningLexicalItems),
          row.readTable(sense),
          isNew: row.read(isNew)!,
        ),
    ];
  }

  JoinedSelectStatement _queue(
    String language, {
    String? groupId,
    DateTime? dueBefore,
    bool contextsOnly = false,
    bool includeCards = true,
  }) {
    final i = db.learningLexicalItems;
    final s = db.learningLexicalSenses;
    final r = db.learningReviewSchedules;
    final g = db.learningGroupItems;
    final joins = [
      innerJoin(i, i.id.equalsExp(s.itemId), useColumns: includeCards),
      innerJoin(r, r.senseId.equalsExp(s.id), useColumns: false),
      if (groupId != null)
        innerJoin(
          g,
          g.senseId.equalsExp(s.id) & g.groupId.equals(groupId),
          useColumns: false,
        ),
    ];
    final query = includeCards
        ? db.select(s).join(joins)
        : db.selectOnly(s).join(joins);
    query.where(i.language.equals(language) & s.deletedAt.isNull());
    if (dueBefore != null) query.where(_isDue(dueBefore));
    if (contextsOnly) query.where(s.application.isNotNull());
    return query;
  }

  Future<void> recordRecall({
    required String attemptId,
    required String senseId,
    required RecallRating rating,
    required bool groupPrompt,
    RecallKind kind = RecallKind.scheduled,
    DateTime? selectedAt,
    DateTime? now,
  }) => runOperation(() async {
    final time = (now ?? DateTime.now()).toUtc();
    await db.transaction(() async {
      await _activeSense(senseId);
      final schedule = await (db.select(
        db.learningReviewSchedules,
      )..where((row) => row.senseId.equals(senseId))).getSingle();
      final eligibilityTime = selectedAt != null && selectedAt.isBefore(time)
          ? selectedAt
          : time;
      final actualKind =
          kind == RecallKind.scheduled &&
              schedule.repetitions > 0 &&
              schedule.dueAt.isAfter(eligibilityTime)
          ? RecallKind.practice
          : kind;
      final inserted = await _insertEvidence(
        LearningEvidenceCompanion.insert(
          id: attemptId,
          senseId: senseId,
          skill: "meaningRecall",
          rating: Value(rating.name),
          recallKind: Value(actualKind.name),
          answerRevealed: const Value(true),
          groupPrompt: Value(groupPrompt),
          occurredAt: time,
        ),
      );
      if (!inserted || actualKind != RecallKind.scheduled) return;
      final settings = await loadVocabularyReviewSettings(db);
      final memory = switch (schedule) {
        LearningReviewSchedule(
          fsrsVersion: Fsrs.version,
          stability: final double stability,
          difficulty: final double difficulty,
        )
            when stability.isFinite &&
                stability >= .001 &&
                difficulty >= 1 &&
                difficulty <= 10 =>
          (stability: stability, difficulty: difficulty),
        _ => null,
      };
      final result = settings.enabled
          ? Fsrs(
              retentionPercent: settings.retentionPercent,
              maximumInterval: settings.maximumInterval,
            ).review(
              rating: rating,
              now: time,
              previous: memory,
              lastReview: schedule.updatedAt,
            )
          : null;
      final days =
          result?.intervalDays ??
          switch (rating) {
            RecallRating.again => 1,
            RecallRating.hard => 2,
            RecallRating.good => (schedule.intervalDays * 2).clamp(3, 90),
            RecallRating.easy => (schedule.intervalDays * 3).clamp(7, 180),
          };
      await (db.update(
        db.learningReviewSchedules,
      )..where((row) => row.senseId.equals(senseId))).write(
        LearningReviewSchedulesCompanion(
          dueAt: Value(result?.dueAt ?? time.add(Duration(days: days))),
          intervalDays: Value(days),
          repetitions: Value(schedule.repetitions + 1),
          updatedAt: Value(time),
          fsrsVersion: Value(result == null ? null : Fsrs.version),
          stability: Value(result?.memory.stability),
          difficulty: Value(result?.memory.difficulty),
        ),
      );
    });
    changed();
  });

  Future<LearningEvidenceData> recordApplication({
    required String attemptId,
    required String senseId,
    required String answer,
    required bool usedHelp,
    required bool groupPrompt,
  }) => runOperation(() async {
    final result = await db.transaction(() async {
      final sense = await _activeSense(senseId);
      final expected = sense.applicationAnswer;
      if (sense.application == null ||
          expected == null ||
          answer.trim().isEmpty) {
        throw StateError("No valid application response");
      }
      await _insertEvidence(
        LearningEvidenceCompanion.insert(
          id: attemptId,
          senseId: senseId,
          skill: "contextApplication",
          answer: Value(answer.trim()),
          correct: Value(
            normalizeLanguageText(answer) == normalizeLanguageText(expected),
          ),
          answerRevealed: Value(usedHelp),
          groupPrompt: Value(groupPrompt),
          occurredAt: DateTime.now(),
        ),
      );
      return (db.select(
        db.learningEvidence,
      )..where((row) => row.id.equals(attemptId))).getSingle();
    });
    changed();
    return result;
  });

  Future<LearningLexicalSense> _activeSense(String id) async {
    final sense = await (db.select(
      db.learningLexicalSenses,
    )..where((row) => row.id.equals(id))).getSingle();
    if (sense.deletedAt != null) throw _wordInTrash;
    return sense;
  }

  Future<bool> _insertEvidence(LearningEvidenceCompanion evidence) async {
    final generation = await LanguageGenerationStore(db)
        .currentContentRun("vocabulary", evidence.senseId.value);
    evidence = evidence.copyWith(generationRunId: Value(generation?.id));
    final rows = await db
        .into(db.learningEvidence)
        .insertReturningOrNull(evidence, mode: InsertMode.insertOrIgnore);
    return rows != null;
  }

  Stream<List<LearningEvidenceData>> recentEvidence(String language) {
    final e = db.learningEvidence;
    final s = db.learningLexicalSenses;
    final i = db.learningLexicalItems;
    final q =
        db.select(e).join([
            innerJoin(s, s.id.equalsExp(e.senseId), useColumns: false),
            innerJoin(i, i.id.equalsExp(s.itemId), useColumns: false),
          ])
          ..where(i.language.equals(language))
          ..orderBy([OrderingTerm.desc(e.occurredAt)])
          ..limit(30);
    return q.watch().map(
      (rows) => rows.map((row) => row.readTable(e)).toList(),
    );
  }

  static String? _optional(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
