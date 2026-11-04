import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/features/library/study_store.dart';
import 'package:tixun/core/platform/attachment_store.dart';

import 'dart:io';

import 'generated_migrations/schema.dart';

void main() {
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
    await verifier.migrateAndValidate(db, 4);
    expect((await db.select(db.practiceAttempts).get()).single.status, 'draft');
    expect((await db.select(db.practiceResponses).get()).single.answer, '4');
    expect(await db.select(db.reviewSchedules).get(), isEmpty);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test(
    'Schema v1 upgrades to v4 without losing chats, drafts, images or settings',
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
      await verifier.migrateAndValidate(db, 4);
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
}
