import "dart:convert";

import "package:drift_dev/api/migrations_native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/sentence_batch_store.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_models.dart";
import "package:tixun/features/language_learning/quick_lookup/quick_store.dart";

import "../../generated_migrations/schema.dart";
import "../../support/quick_lookup.dart";

void main() {
  test("v32 lookup history starts outside Trash after upgrade", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(32);
    final raw = schema.rawDatabase;
    raw.execute("""
      INSERT INTO language_quick_actions
      (id, name, icon, description, input_hint, prompt, source_language, target_language,
       gloss_language, detailed, position, built_in, enabled, revision, created_at, updated_at)
      VALUES ('action', 'Meaning', 'meaning', '', '', 'prompt', 'auto', 'en',
              'zh', 0, 0, 1, 1, 1, 1, 1)
      """);
    raw.execute("""
      INSERT INTO language_quick_lookups
      (id, action_id, action_name, prompt, action_revision, schema_revision, input,
       source_language, target_language, gloss_language, level, detailed, summary,
       content, candidates, provider, model, cache_key, created_at)
      VALUES ('lookup', 'action', 'Meaning', 'prompt', 1, 1, 'pleasure',
              'auto', 'en', 'zh', 'beginner', 0, 'summary',
              'content', '{}', 'mock', 'model', 'key', 1)
      """);
    final db = AppDatabase(schema.newConnection());
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });

    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect((await store.quickHistory()).single.id, "lookup");
    expect(await store.quickHistory(trashed: true), isEmpty);
    expect((await store.cachedQuickLookup("key"))?.content, "content");
    await store.trashQuickLookups({"lookup"});
    expect((await store.quickHistory(trashed: true)).single.id, "lookup");
  });

  test(
    "v31 vocabulary remains active with its FSRS state after upgrade",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(31);
      final raw = schema.rawDatabase;
      raw.execute(
        "INSERT INTO learning_lexical_items(id,language,form,normalized_form,created_at) VALUES('go','en','go','go',1)",
      );
      raw.execute(
        "INSERT INTO learning_lexical_senses(id,item_id,meaning,created_at) VALUES('sense','go','去',1)",
      );
      raw.execute(
        "INSERT INTO learning_vocabulary_groups(id,language,title,created_at) VALUES('group','en','Travel',1)",
      );
      raw.execute(
        "INSERT INTO learning_group_items(group_id,sense_id) VALUES('group','sense')",
      );
      raw.execute(
        "INSERT INTO learning_review_schedules(sense_id,due_at,repetitions,updated_at,fsrs_version,stability,difficulty) VALUES('sense',100,3,1,'6',4.5,2.1)",
      );
      final db = AppDatabase(schema.newConnection());
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });

      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final active = await store.cards(language: "en", groupId: "group");
      expect(active.single.sense.deletedAt, isNull);
      expect(await store.trashedCards("en").first, isEmpty);
      final progress = await db.select(db.learningReviewSchedules).getSingle();
      expect(progress.stability, 4.5);
      expect(progress.difficulty, 2.1);
      expect(progress.repetitions, 3);
    },
  );

  test("v21 upgrade preserves study data and enables offline vocabulary", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(21);
    schema.rawDatabase.execute(
      "INSERT INTO exam_events(id,title,date,updated_at) VALUES('e','期中',1,1)",
    );
    final db = AppDatabase(schema.newConnection());
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });

    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect((await db.select(db.examEvents).get()).single.title, "期中");
    await store.saveEntries(
      language: "en",
      groupTitle: "Travel",
      groupType: VocabularyGroupType.topic,
      entries: const [VocabularyEntry(form: "ticket", meaning: "车票")],
    );
    expect(await store.dueCount("en").first, 0);
    expect(await store.cards(language: "en"), hasLength(1));
  });

  test(
    "v22 sentence cards reopen unchanged when exam tables are added",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(22);
      schema.rawDatabase.execute(
        "INSERT INTO learning_sentence_batches "
        "(id, language, topic, style, gloss_language, model, prompt_version, is_mock, cards, generated_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          "existing",
          "en",
          "dailyLife",
          "written",
          "zh",
          "legacy-model",
          1,
          0,
          '[{"id":"legacy","text":"It is raining.","hint":"Weather.",'
              '"translation":"下雨了。","level":"beginner","revision":1}]',
          1,
        ],
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final saved = await db.select(db.learningSentenceBatches).getSingle();
      final card = openSavedSentenceBatch(saved).cards.single;
      expect(card.id, "legacy");
      expect(card.choices, isEmpty);
      expect(await db.select(db.learningExamMaterials).get(), isEmpty);
      expect(await db.select(db.learningExamAttempts).get(), isEmpty);
    },
  );

  test("v24 upgrade preserves writing tasks and adds indexed, linked lookup history", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(24);
    schema.rawDatabase.execute(
      "INSERT INTO learning_writing_tasks "
      "(id,kind,profile,level,topic,title,prompt,model,prompt_version,created_at) "
      "VALUES ('old','continuation','profile','beginner','topic','Older task','prompt','model',1,1)",
    );
    final db = AppDatabase(schema.newConnection());
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect(
      (await db.select(db.learningWritingTasks).getSingle()).title,
      "Older task",
    );
    await store.ensureQuickActions();
    final lookup = await store.saveQuickLookup(
      quickTestQuery((await store.quickActions())[1]),
      QuickAnswer.parse(jsonDecode(validQuickReply)),
      config: quickTestConfig,
      key: "migrated",
    );
    expect(
      (await store.quickHistory(search: "MY PLEASURE")).single.id,
      lookup.id,
    );
    expect((await store.quickHistory(search: "快乐")).single.id, lookup.id);
    await store.saveEntries(
      language: "en",
      groupTitle: "Migrated",
      groupType: VocabularyGroupType.topic,
      quickLookupId: lookup.id,
      entries: const [VocabularyEntry(form: "pleasure", meaning: "愉悦")],
    );
    expect(await db.select(db.languageQuickLearningLinks).get(), hasLength(1));
    await store.trashQuickLookups({lookup.id});
    expect(await store.quickHistory(search: "MY PLEASURE"), isEmpty);
    expect(
      (await store.quickHistory(
        trashed: true,
        search: "MY PLEASURE",
      )).single.id,
      lookup.id,
    );
    expect(await db.select(db.languageQuickLearningLinks).get(), hasLength(1));
    await store.deleteTrashedQuickLookups({lookup.id});
    expect(
      await store.quickHistory(trashed: true, search: "MY PLEASURE"),
      isEmpty,
    );
    expect(await db.select(db.languageQuickLearningLinks).get(), isEmpty);
    expect(await db.select(db.learningLexicalSenses).get(), hasLength(1));
    expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
  });
  test(
    "v26 keeps vocabulary and review progress while adding word forms",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(26);
      schema.rawDatabase.execute(
        "INSERT INTO learning_lexical_items(id,language,form,normalized_form,created_at) VALUES('go','en','go','go',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO learning_lexical_senses(id,item_id,meaning,created_at) VALUES('sense','go','去',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO learning_review_schedules(sense_id,due_at,interval_days,repetitions,updated_at) VALUES('sense',100,14,3,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO learning_evidence(id,sense_id,skill,occurred_at) VALUES('attempt','sense','meaningRecall',1)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      expect(
        (await db.select(db.learningLexicalSenses).getSingle()).meaning,
        "去",
      );
      expect(
        (await db.select(db.learningReviewSchedules).getSingle()).intervalDays,
        14,
      );
      expect((await db.select(db.learningEvidence).getSingle()).formId, isNull);
      expect(await db.select(db.learningLexicalForms).get(), isEmpty);
    },
  );
}
