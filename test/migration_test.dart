import "package:drift/drift.dart" hide isNull;
import "package:drift_dev/api/migrations_native.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/library/study_store.dart";
import "package:tixun/core/platform/attachment_store.dart";

import "dart:io";

import "generated_migrations/schema.dart";

part "migration_early_cases.dart";

void main() {
  test(
    "Schema v21 keeps legacy chat messages without inventing context",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(20);
      schema.rawDatabase.execute(
        "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','Legacy',1,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,created_at) VALUES('u','s','user','question',1)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      expect((await db.messages("s")).single.content, "question");
      expect(await db.select(db.chatContextEvents).get(), isEmpty);
    },
  );

  test(
    "Schema v20 preserves existing usage and marks breakdown unavailable",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(19);
      schema.rawDatabase.execute(
        "INSERT INTO ai_usage_events(id,action_id,provider_kind,model,feature,status,occurred_at) VALUES('u','a','deepseek','deepseek-flash','chat','complete',1)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final event = (await db.select(db.aiUsageEvents).get()).single;
      expect(event.id, "u");
      expect(event.tokenBreakdownJson, isNull);
    },
  );

  test("Schema v19 adds the timeline without changing exam records", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(18);
    schema.rawDatabase.execute(
      "INSERT INTO exam_events(id,title,date,updated_at) VALUES('e','期中',1,1)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect((await db.select(db.examEvents).get()).single.title, "期中");
    expect(await db.select(db.timelineEvents).get(), isEmpty);
  });

  test("Schema v18 keeps existing pins as question figures", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(17);
    schema.rawDatabase.execute(
      "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','Legacy',1,1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO practice_questions(id,kind,stem,subject,origin,created_at) VALUES('q','numeric','2+2','数学','manual',1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO visual_scenes(id,scene_json,revision,created_at,updated_at) VALUES('v','{}',3,1,1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO visual_scene_revisions(visual_id,revision,scene_json,created_at) VALUES('v',3,'{}',1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO visual_question_links(visual_id,question_id,revision) VALUES('v','q',3)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    final link = (await db.select(db.visualQuestionLinks).get()).single;
    expect(link.role, "question");
    expect(link.revision, 3);
    expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
  });

  test(
    "Schema v16 adds visual scenes and links without touching old rows",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(15);
      schema.rawDatabase.execute(
        "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','旧会话',1,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,created_at) VALUES('m','s','assistant','请看图',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO practice_questions(id,kind,stem,subject,origin,created_at) VALUES('q','numeric','2+2','数学','ai',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO knowledge_items(id,title,content,subject,chapter,created_at,updated_at) VALUES('k','旧知识','正文','数学','旧章节',1,1)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      expect((await db.select(db.chatMessages).get()).single.content, "请看图");
      expect((await db.select(db.practiceQuestions).get()).single.stem, "2+2");
      expect((await db.select(db.knowledgeItems).get()).single.title, "旧知识");
      expect(await db.select(db.visualScenes).get(), isEmpty);
      expect(await db.select(db.visualSceneRevisions).get(), isEmpty);
      expect(await db.select(db.visualMessageLinks).get(), isEmpty);
      expect(await db.select(db.visualQuestionLinks).get(), isEmpty);
      expect(await db.select(db.visualStudyLinks).get(), isEmpty);
      expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
      expect(
        (await db.customSelect("PRAGMA integrity_check").getSingle())
            .data
            .values
            .single,
        "ok",
      );
    },
  );

  test(
    "Schema v17 adds the pinned revision to question visual links",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(16);
      schema.rawDatabase.execute(
        "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','旧会话',1,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,created_at) VALUES('m','s','assistant','请看图',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO practice_questions(id,kind,stem,subject,origin,created_at) VALUES('q','numeric','2+2','数学','ai',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO visual_scenes(id,scene_json,revision,created_at,updated_at) VALUES('v','{}',1,1,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO visual_scene_revisions(visual_id,revision,scene_json,created_at) VALUES('v',1,'{}',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO visual_question_links(visual_id,question_id) VALUES('v','q')",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final links = await db.select(db.visualQuestionLinks).get();
      expect(links, hasLength(1));
      expect(links.single.revision, 1);
      expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
      expect(
        (await db.customSelect("PRAGMA integrity_check").getSingle())
            .data
            .values
            .single,
        "ok",
      );
    },
  );

  test(
    "Schema v13 preserves legacy aggregate tokens without inventing a split",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(13);
      schema.rawDatabase.execute(
        "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','Legacy',1,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,model,total_tokens,created_at) VALUES('m','s','assistant','reply','deepseek-flash',42,2)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final usage = (await db.select(db.aiUsageEvents).get()).single;
      expect(usage.totalTokens, 42);
      expect(usage.inputTokens, isNull);
      expect(usage.cachedInputTokens, isNull);
      expect(usage.outputTokens, isNull);
      expect(usage.usageSource, "legacy_total");
      expect(usage.costBasis, "unknown");
    },
  );

  test("Schema v14 gives built-in DeepSeek prices the off-peak discount", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(14);
    const columns =
        "provider_kind,endpoint,model,input_rate_nano_usd_per_million,"
        "cached_input_rate_nano_usd_per_million,"
        "output_rate_nano_usd_per_million,source,updated_at";
    schema.rawDatabase.execute(
      "INSERT INTO ai_model_prices($columns) VALUES('deepseek','https://api.deepseek.com','deepseek-flash',300000000,6000000,1200000000,'deepseek_official_peak',1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO ai_model_prices($columns) VALUES('compatible','https://api.example.test','model-x',1000000000,100000000,2000000000,'user',1)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    final prices = await db.select(db.aiModelPrices).get();
    final builtin = prices.singleWhere(
      (row) => row.source == "deepseek_official_peak",
    );
    final user = prices.singleWhere((row) => row.source == "user");
    expect(builtin.offPeakDiscountPercent, 50);
    expect(user.offPeakDiscountPercent, 0);
  });

  test("Schema v12 adds context summary columns to chat sessions", () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(12);
    schema.rawDatabase.execute(
      "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s','旧会话','',1,1)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    final session = (await db.sessions()).single;
    expect(session.contextSummary, isNull);
    expect(session.contextSummaryUpToId, isNull);
    await db.setContextSummary("s", "已学二次函数", "m1");
    final updated = (await db.sessions()).single;
    expect(updated.contextSummary, "已学二次函数");
    expect(updated.contextSummaryUpToId, "m1");
    expect(await db.customSelect("PRAGMA foreign_key_check").get(), isEmpty);
  });

  test(
    "Schema v11 keeps exam photo references while adding original preservation",
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(11);
      schema.rawDatabase.execute(
        "INSERT INTO exam_events(id,title,date,updated_at) VALUES('e','Exam',0,0)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO exam_subjects(id,event_id,subject,updated_at) VALUES('s','e','数学',0)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO exam_attachments(id,subject_id,role,relative_path,mime,created_at) VALUES('p','s','sheet','attachments/old.png','image/png',0)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final photo = (await db.select(db.examAttachments).get()).single;
      expect(photo.relativePath, "attachments/old.png");
      expect(photo.originalPath, isNull);
    },
  );

  _earlyMigrationCases();
}
