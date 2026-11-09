import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/core/platform/attachment_store.dart';

import 'dart:io';

import 'generated_migrations/schema.dart';

void main() {
  test(
    'Schema v11 keeps exam photo references while adding original preservation',
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
      expect(photo.relativePath, 'attachments/old.png');
      expect(photo.originalPath, isNull);
    },
  );

  for (final kind in ['chatgpt', 'deepseek', 'compatible']) {
    test('Schema v10 preserves old max semantics for $kind', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(10);
      final model = kind == 'chatgpt'
          ? 'gpt-6.1-sol'
          : kind == 'deepseek'
          ? 'deepseek-flash'
          : 'gateway-model';
      final url = kind == 'deepseek'
          ? 'https://api.deepseek.com'
          : 'https://api.openai.com/v1';
      schema.rawDatabase.execute(
        "INSERT INTO provider_configs(id,kind,model,base_url,effort,thinking) VALUES(1,'$kind','$model','$url','max',1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO preferences(name,value) VALUES('ai_reasoning:s','max')",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      expect((await db.config()).effort, kind == 'chatgpt' ? 'xhigh' : 'max');
      expect(
        await db.preference('ai_reasoning:s'),
        kind == 'chatgpt' ? 'xhigh' : 'max',
      );
      expect((await db.config()).reasoningLevels, isNull);
    });
  }

  test('Schema v9 upgrade preserves exam scores and leaves existing chapters unclassified', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(9);
    schema.rawDatabase.execute(
      "INSERT INTO exam_events(id,title,date,updated_at) VALUES('e','期中',1,1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO exam_subjects(id,event_id,subject,raw_score,updated_at) VALUES('s','e','数学',121,1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO knowledge_items(id,title,content,subject,chapter,created_at,updated_at) VALUES('k','旧知识','正文','数学','旧章节',1,1)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect((await db.select(db.examSubjects).get()).single.rawScore, 121);
    expect((await db.select(db.knowledgeItems).get()).single.chapter, '旧章节');
    expect(await db.select(db.subjectModules).get(), isEmpty);
    expect(await db.select(db.knowledgeModuleLinks).get(), isEmpty);
    expect(await db.select(db.mistakeModuleLinks).get(), isEmpty);
  });

  test(
    'Schema v8 upgrade preserves scratchpads and creates empty exam tables',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(8);
      schema.rawDatabase.execute(
        "INSERT INTO scratchpads(context_key,document,updated_at) VALUES('chat:test','saved draft',1)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      expect(
        (await db.select(db.scratchpads).get()).single.document,
        'saved draft',
      );
      expect(await db.select(db.examEvents).get(), isEmpty);
      expect(await db.select(db.examSubjects).get(), isEmpty);
      expect(await db.select(db.examScoreRows).get(), isEmpty);
      expect(await db.select(db.examAttachments).get(), isEmpty);
    },
  );

  test(
    'Schema v4 backfills quiz chat links and preserves image references',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(4);
      final raw = schema.rawDatabase;
      raw.execute(
        "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s','已有训练','草稿',1,1)",
      );
      raw.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,created_at) VALUES('m','s','assistant','请独立完成',1)",
      );
      raw.execute(
        "INSERT INTO attachments(id,session_id,relative_path,mime,byte_length) VALUES('i','s','attachments/raw.png','image/png',12)",
      );
      raw.execute(
        "INSERT INTO practice_questions(id,kind,stem,subject,origin,source_message_id,created_at) VALUES('q','numeric','2+2','数学','ai','m',1)",
      );
      raw.execute(
        "INSERT INTO practice_attempts(id,question_id,started_at) VALUES('a','q',1)",
      );
      raw.execute(
        "INSERT INTO practice_responses(attempt_id,position,answer) VALUES('a',0,'4')",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final link = (await db.select(db.practiceChatLinks).get()).single;
      expect(link.messageId, 'm');
      expect(link.questionId, 'q');
      expect((await db.images('s')).single.originalPath, isNull);
      expect((await db.images('s')).single.relativePath, 'attachments/raw.png');
      expect((await db.select(db.practiceResponses).get()).single.answer, '4');
      expect((await db.sessions()).single.draft, '草稿');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test('Schema v3 preserves pending answers when adding reviews', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase.execute(
      "INSERT INTO practice_questions(id,kind,stem,subject,origin,created_at) VALUES('q','numeric','2+2','数学','manual',1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO practice_answer_keys(question_id,position,answer) VALUES('q',0,'4')",
    );
    schema.rawDatabase.execute(
      "INSERT INTO practice_attempts(id,question_id,started_at) VALUES('a','q',1)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO practice_responses(attempt_id,position,answer) VALUES('a',0,'4')",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    expect((await db.select(db.practiceAttempts).get()).single.status, 'draft');
    expect((await db.select(db.practiceResponses).get()).single.answer, '4');
    expect(await db.select(db.reviewSchedules).get(), isEmpty);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test(
    'Schema v1 upgrades to v8 without losing chats, drafts, images or settings',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(1);
      final raw = schema.rawDatabase;
      // Runtime FTS entities and triggers were present in v1 outside Drift's table declarations.
      raw.execute(
        "CREATE VIRTUAL TABLE message_search USING fts5(content, session_id UNINDEXED, content='chat_messages', content_rowid='rowid', tokenize='trigram')",
      );
      raw.execute(
        'CREATE TRIGGER messages_ai AFTER INSERT ON chat_messages BEGIN INSERT INTO message_search(rowid,content,session_id) VALUES(new.rowid,new.content,new.session_id); END',
      );
      raw.execute(
        "CREATE TRIGGER messages_ad AFTER DELETE ON chat_messages BEGIN INSERT INTO message_search(message_search,rowid,content,session_id) VALUES('delete',old.rowid,old.content,old.session_id); END",
      );
      raw.execute(
        "CREATE TRIGGER messages_au AFTER UPDATE ON chat_messages BEGIN INSERT INTO message_search(message_search,rowid,content,session_id) VALUES('delete',old.rowid,old.content,old.session_id); INSERT INTO message_search(rowid,content,session_id) VALUES(new.rowid,new.content,new.session_id); END",
      );
      raw.execute(
        "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s','旧版会话','未发送草稿',1,1)",
      );
      raw.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,created_at) VALUES('m','s','user','通过配方法理解二次函数',1)",
      );
      raw.execute(
        "INSERT INTO attachments(id,session_id,message_id,relative_path,mime,byte_length) VALUES('a','s','m','attachments/original.png','image/png',12)",
      );
      raw.execute(
        "INSERT INTO provider_configs(id,kind,base_url,model) VALUES(1,'compatible','https://example.com/v1','custom-model')",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      expect((await db.sessions()).single.draft, '未发送草稿');
      expect((await db.sessions('二次函数')).single.id, 's');
      expect(
        (await db.images('s')).single.relativePath,
        'attachments/original.png',
      );
      expect((await db.config()).model, 'custom-model');
      expect((await db.config()).supportsTools, false);
      expect((await db.sessions()).single.toolsEnabled, false);
      final root = await Directory.systemTemp.createTemp('tixun-migration');
      addTearDown(() => root.delete(recursive: true));
      final store = StudyStore(db, AttachmentStore(root));
      addTearDown(store.dispose);
      final note = await store.saveKnowledge(
        const KnowledgeDraft(title: '升级后新知识', content: '旧版资料与新知识共存。'),
      );
      expect((await store.searchKnowledge(query: '新知识')).single.id, note.id);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data
            .values
            .single,
        'ok',
      );
    },
  );

  test('Schema v5 adds reasoning_content to chat messages', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    final raw = schema.rawDatabase;
    raw.execute(
      "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s','会话','',1,1)",
    );
    raw.execute(
      "INSERT INTO chat_messages(id,session_id,role,content,created_at) VALUES('m','s','assistant','请独立完成',1)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    final migrated = (await db.select(db.chatMessages).get()).single;
    expect(migrated.reasoningContent, isNull);
    expect(migrated.content, '请独立完成');
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            id: 'm2',
            sessionId: 's',
            role: 'assistant',
            content: '已出题',
            reasoningContent: const Value('先想再答'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(2),
          ),
        );
    final written = (await db.select(db.chatMessages).get()).firstWhere(
      (m) => m.id == 'm2',
    );
    expect(written.reasoningContent, '先想再答');
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test('Schema v6 backfills session subjects from the title prefix', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(6);
    final raw = schema.rawDatabase;
    raw.execute(
      "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s1','数学 · 检测训练','',1,1)",
    );
    raw.execute(
      "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s2','物理 · 受力分析的学习计划','',1,1)",
    );
    raw.execute(
      "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s3','英语阅读：怎样理解长难句','',1,1)",
    );
    raw.execute(
      "INSERT INTO chat_sessions(id,title,draft,created_at,updated_at) VALUES('s4','二次函数：从配方理解顶点','',1,1)",
    );
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
    final byId = {for (final s in await db.sessions()) s.id: s};
    expect(byId['s1']!.subject, '数学');
    expect(byId['s2']!.subject, '物理');
    expect(byId['s3']!.subject, isNull);
    expect(byId['s4']!.subject, isNull);
    final created = await db.createSession(title: '新建', subject: '化学');
    expect(created.subject, '化学');
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test(
    'Schema v7 preserves old reasoning while adding traces and scratchpads',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(7);
      schema.rawDatabase.execute(
        "INSERT INTO chat_sessions(id,title,created_at,updated_at) VALUES('s','旧会话',1,1)",
      );
      schema.rawDatabase.execute(
        "INSERT INTO chat_messages(id,session_id,role,content,reasoning_content,created_at) VALUES('m','s','assistant','正文','旧思考',1)",
      );
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, AppDatabase.latestSchemaVersion);
      final message = (await db.messages('s')).single;
      expect(message.reasoningContent, '旧思考');
      expect(message.reasoningTrace, isNull);
      expect(await db.select(db.scratchpads).get(), isEmpty);
    },
  );
}
