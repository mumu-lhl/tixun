import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/language_learning/language_store.dart';
import 'package:tixun/features/language_learning/sentence_batch_store.dart';

import 'generated_migrations/schema.dart';

void main() {
  test('v21 upgrade preserves study data and enables offline vocabulary', () async {
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
    expect((await db.select(db.examEvents).get()).single.title, '期中');
    await store.saveEntries(
      language: 'en',
      groupTitle: 'Travel',
      groupType: VocabularyGroupType.topic,
      entries: const [VocabularyEntry(form: 'ticket', meaning: '车票')],
    );
    expect(await store.dueCount('en').first, 1);
  });

  test(
    'v22 sentence cards reopen unchanged when exam tables are added',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(22);
      schema.rawDatabase.execute(
        'INSERT INTO learning_sentence_batches '
        '(id, language, topic, style, gloss_language, model, prompt_version, is_mock, cards, generated_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'existing',
          'en',
          'dailyLife',
          'written',
          'zh',
          'legacy-model',
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
      expect(card.id, 'legacy');
      expect(card.choices, isEmpty);
      expect(await db.select(db.learningExamMaterials).get(), isEmpty);
      expect(await db.select(db.learningExamAttempts).get(), isEmpty);
    },
  );
}
