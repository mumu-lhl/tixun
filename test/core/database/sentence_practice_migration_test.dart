import "package:drift_dev/api/migrations_native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";

import "../../generated_migrations/schema.dart";

void main() {
  test("v33 migration classifies known contexts and preserves previous sentence evidence", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final old = await verifier.schemaAt(33);
    final sql = old.rawDatabase;
    const cards = '[{"skill":"meaningInContext","text":"Previously saved"}]';
    for (final id in ["context", "quick:1", "old-cloze"]) {
      sql.execute(
        "INSERT INTO learning_sentence_batches "
        "(id,language,topic,style,gloss_language,model,prompt_version,is_mock,cards,generated_at) "
        "VALUES(?,'en','travel','written','en','model',3,0,?,1)",
        [id, cards],
      );
    }
    sql.execute(
      "INSERT INTO language_generation_tasks(id,feature) VALUES('t','language_context_understanding')",
    );
    sql.execute(
      "INSERT INTO language_generation_runs(id,task_id,input_json,model,options_json,output,format,created_at) "
      "VALUES('r','t','{}','model','{}','{}','json',1)",
    );
    sql.execute(
      "INSERT INTO language_generation_links(kind,content_id,selection_order,run_id) "
      "VALUES('sentence_batch','context',0,'r')",
    );
    sql.execute(
      "INSERT INTO learning_sentence_attempts "
      "(id,batch_id,sentence_id,revision,language,sentence,skill,rating,answer,correct,help_before_answer,help_used,occurred_at) "
      "VALUES('a','attempt','sentence',2,'en','Previously saved','meaningInContext','understood','choice',1,0,1,1)",
    );

    final db = AppDatabase(old.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);

    final batches = await db.select(db.learningSentenceBatches).get();
    expect(
      {for (final batch in batches) batch.id: batch.kind},
      {"context": "newContext", "quick:1": "sentence", "old-cloze": "sentence"},
    );
    expect(batches.map((batch) => batch.cards), everyElement(cards));
    final attempt = await db.select(db.learningSentenceAttempts).getSingle();
    expect(attempt.revision, 2);
    expect(attempt.rating, "understood");
    expect(attempt.correct, isTrue);
    expect(attempt.helpBeforeAnswer, 0);
    expect(attempt.targetSenseId, isNull);
    expect(
      (await db
              .customSelect("PRAGMA index_list(learning_sentence_attempts)")
              .get())
          .map((index) => index.read<String>("name")),
      contains("learning_sentence_target"),
    );
    expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
  });
}
