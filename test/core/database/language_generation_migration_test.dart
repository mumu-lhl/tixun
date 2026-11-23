import "package:drift_dev/api/migrations_native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";

import "../../generated_migrations/schema.dart";

void main() {
  test("v29 upgrade preserves old learning content and leaves unavailable provenance unknown", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final old = await verifier.schemaAt(29);
    old.rawDatabase.execute(
      "INSERT INTO learning_vocabulary_groups(id,language,title,group_type,created_at) VALUES('g','en','Travel','topic',1)",
    );
    old.rawDatabase.execute(
      "INSERT INTO learning_lexical_items(id,language,form,normalized_form,lexical_type,created_at) VALUES('i','en','ticket','ticket','word',1)",
    );
    old.rawDatabase.execute(
      "INSERT INTO learning_lexical_senses(id,item_id,meaning,source,ai_model,created_at) VALUES('s','i','车票','ai','old-model',1)",
    );
    old.rawDatabase.execute(
      "INSERT INTO learning_group_items(group_id,sense_id) VALUES('g','s')",
    );
    final db = AppDatabase(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect(
      (await db.select(db.learningVocabularyGroups).get()).single.title,
      "Travel",
    );
    expect(
      (await db.select(db.learningLexicalSenses).get()).single.aiModel,
      "old-model",
    );
    expect(await db.select(db.languageGenerationRuns).get(), isEmpty);
    expect(await db.select(db.languagePromptSnapshots).get(), isEmpty);
    expect((await db.customSelect("PRAGMA foreign_key_check").get()), isEmpty);
  });
}
