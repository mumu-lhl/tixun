import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';
part 'study_tables.dart';
part 'practice_tables.dart';
part 'review_tables.dart';
part 'exam_tables.dart';
part 'module_tables.dart';

class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get subject => text().nullable()();
  TextColumn get mode => text().withDefault(const Constant('guided'))();
  TextColumn get stage => text().withDefault(const Constant('diagnosing'))();
  BoolColumn get toolsEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get draft => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text().customConstraint(
    "NOT NULL CHECK (role IN ('user','assistant'))",
  )();
  TextColumn get content => text()();
  TextColumn get status => text().withDefault(const Constant('complete'))();
  TextColumn get error => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get reasoningContent => text().nullable()();
  TextColumn get reasoningTrace => text().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Scratchpads extends Table {
  TextColumn get contextKey => text()();
  TextColumn get document => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {contextKey};
}

class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get messageId => text().nullable().references(
    ChatMessages,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get relativePath => text()();
  TextColumn get originalPath => text().nullable()();
  TextColumn get mime => text()();
  IntColumn get byteLength => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class ProviderConfigs extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get kind => text().withDefault(const Constant('deepseek'))();
  TextColumn get baseUrl =>
      text().withDefault(const Constant('https://api.deepseek.com'))();
  TextColumn get model =>
      text().withDefault(const Constant('deepseek-flash'))();
  BoolColumn get vision => boolean().withDefault(const Constant(true))();
  BoolColumn get supportsTools => boolean().withDefault(const Constant(true))();
  BoolColumn get thinking => boolean().withDefault(const Constant(false))();
  BoolColumn get supportsThinking =>
      boolean().withDefault(const Constant(true))();
  TextColumn get effort => text().withDefault(const Constant('high'))();
  TextColumn get reasoningLevels => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Preferences extends Table {
  TextColumn get name => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {name};
}

@DriftDatabase(
  tables: [
    ChatSessions,
    ChatMessages,
    Attachments,
    ProviderConfigs,
    Preferences,
    KnowledgeItems,
    KnowledgeRevisions,
    Mistakes,
    KnowledgeTags,
    MistakeTags,
    KnowledgeRelations,
    MistakeKnowledgeLinks,
    StudyAttachments,
    AiToolOperations,
    StudyChatLinks,
    LearningTopics,
    PracticeQuestions,
    PracticeOptions,
    PracticeAnswerKeys,
    PracticeQuestionTopics,
    PracticeQuestionKnowledge,
    PracticeAttempts,
    PracticeResponses,
    PracticeImages,
    ReviewSchedules,
    ReviewRecords,
    PracticeChatLinks,
    Scratchpads,
    ExamEvents,
    ExamSubjects,
    ExamScoreRows,
    ExamAttachments,
    SubjectModules,
    KnowledgeModuleLinks,
    MistakeModuleLinks,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  factory AppDatabase.file(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());
  static const latestSchemaVersion = 11;
  @override
  int get schemaVersion => latestSchemaVersion;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createStudyIndexes();
      await _createPracticeIndexes();
      await _createReviewIndexes();
      await _createPracticeLinkIndex();
      await _createModuleIndexes();
      await _createExamIndexes();
      await customStatement(
        'CREATE INDEX messages_session_time ON chat_messages(session_id, created_at)',
      );
      await customStatement(
        'CREATE INDEX attachments_message ON attachments(message_id)',
      );
      await customStatement(
        "CREATE VIRTUAL TABLE message_search USING fts5(content, session_id UNINDEXED, content='chat_messages', content_rowid='rowid', tokenize='trigram')",
      );
      await customStatement(
        "CREATE TRIGGER messages_ai AFTER INSERT ON chat_messages BEGIN INSERT INTO message_search(rowid, content, session_id) VALUES (new.rowid, new.content, new.session_id); END",
      );
      await customStatement(
        "CREATE TRIGGER messages_ad AFTER DELETE ON chat_messages BEGIN INSERT INTO message_search(message_search, rowid, content, session_id) VALUES ('delete', old.rowid, old.content, old.session_id); END",
      );
      await customStatement(
        "CREATE TRIGGER messages_au AFTER UPDATE ON chat_messages BEGIN INSERT INTO message_search(message_search, rowid, content, session_id) VALUES ('delete', old.rowid, old.content, old.session_id); INSERT INTO message_search(rowid, content, session_id) VALUES (new.rowid, new.content, new.session_id); END",
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(chatSessions, chatSessions.toolsEnabled);
        await m.addColumn(providerConfigs, providerConfigs.supportsTools);
        await customStatement(
          "UPDATE provider_configs SET supports_tools = 0 WHERE kind <> 'deepseek'",
        );
        for (final table in <TableInfo>[
          knowledgeItems,
          knowledgeRevisions,
          mistakes,
          knowledgeTags,
          mistakeTags,
          knowledgeRelations,
          mistakeKnowledgeLinks,
          studyAttachments,
          aiToolOperations,
          studyChatLinks,
        ]) {
          await m.createTable(table);
        }
        await _createStudyIndexes();
      }
      if (from < 3) {
        for (final table in <TableInfo>[
          learningTopics,
          practiceQuestions,
          practiceOptions,
          practiceAnswerKeys,
          practiceQuestionTopics,
          practiceQuestionKnowledge,
          practiceAttempts,
          practiceResponses,
          practiceImages,
        ]) {
          await m.createTable(table);
        }
        await _createPracticeIndexes();
      }
      if (from < 4) {
        await customStatement('DROP INDEX IF EXISTS tool_write_dedup');
        await customStatement(
          "CREATE UNIQUE INDEX tool_write_dedup ON ai_tool_operations(run_id,name,arguments) WHERE name IN ('create_knowledge','update_knowledge','delete_knowledge','create_mistake','update_mistake','delete_mistake','link_mistake_to_knowledge','schedule_review') AND status IN ('pending','running','succeeded')",
        );
        await m.createTable(reviewSchedules);
        await m.createTable(reviewRecords);
        await _createReviewIndexes();
      }
      if (from < 5) {
        await m.addColumn(attachments, attachments.originalPath);
        await m.createTable(practiceChatLinks);
        await _createPracticeLinkIndex();
        await customStatement(
          'INSERT INTO practice_chat_links(question_id,message_id) SELECT id,source_message_id FROM practice_questions WHERE source_message_id IS NOT NULL',
        );
      }
      if (from < 6) {
        await m.addColumn(chatMessages, chatMessages.reasoningContent);
      }
      if (from < 7) {
        await m.addColumn(chatSessions, chatSessions.subject);
        // Backfill from the '<subject> · ' title prefix; anything else
        // stays unclassified (null) and only shows under "全部".
        await customStatement(
          "UPDATE chat_sessions SET subject = CASE "
          "WHEN title LIKE '语文 · %' THEN '语文' "
          "WHEN title LIKE '数学 · %' THEN '数学' "
          "WHEN title LIKE '英语 · %' THEN '英语' "
          "WHEN title LIKE '物理 · %' THEN '物理' "
          "WHEN title LIKE '化学 · %' THEN '化学' "
          "WHEN title LIKE '生物 · %' THEN '生物' "
          "WHEN title LIKE '历史 · %' THEN '历史' "
          "WHEN title LIKE '地理 · %' THEN '地理' "
          "WHEN title LIKE '政治 · %' THEN '政治' "
          "ELSE NULL END",
        );
      }
      if (from < 11) {
        await m.addColumn(providerConfigs, providerConfigs.reasoningLevels);
        // Before v11 the ChatGPT UI's "max" was an alias for xhigh. Preserve
        // existing request behavior while making new max a distinct API level.
        await customStatement(
          "UPDATE preferences SET value='xhigh' WHERE name GLOB 'ai_reasoning:*' AND value='max' AND EXISTS(SELECT 1 FROM provider_configs WHERE id=1 AND kind='chatgpt')",
        );
        await customStatement(
          "UPDATE provider_configs SET effort='xhigh' WHERE kind='chatgpt' AND effort='max'",
        );
      }
      if (from < 10) {
        for (final table in <TableInfo>[
          subjectModules,
          knowledgeModuleLinks,
          mistakeModuleLinks,
        ]) {
          await m.createTable(table);
        }
        await _createModuleIndexes();
      }
      if (from < 9) {
        for (final table in <TableInfo>[
          examEvents,
          examSubjects,
          examScoreRows,
          examAttachments,
        ]) {
          await m.createTable(table);
        }
        await _createExamIndexes();
      }
      if (from < 8) {
        await m.addColumn(chatMessages, chatMessages.reasoningTrace);
        await m.createTable(scratchpads);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      for (final owner in {
        'chat_sessions': 'chat',
        'mistakes': 'mistake',
        'practice_questions': 'practice',
      }.entries) {
        await customStatement(
          "CREATE TRIGGER IF NOT EXISTS scratch_delete_${owner.value} AFTER DELETE ON ${owner.key} BEGIN DELETE FROM scratchpads WHERE context_key = '${owner.value}:' || old.id; END",
        );
      }
      await customStatement('PRAGMA journal_mode = WAL');
      await (update(
        aiToolOperations,
      )..where((t) => t.status.isIn(['pending', 'running']))).write(
        const AiToolOperationsCompanion(
          status: Value('cancelled'),
          result: Value('{"ok":false,"error":"应用关闭，未完成的操作已取消。"}'),
        ),
      );
      await (update(
        chatMessages,
      )..where((t) => t.status.equals('generating'))).write(
        const ChatMessagesCompanion(
          status: Value('interrupted'),
          error: Value('上次生成被中断，可重新生成。'),
        ),
      );
    },
  );

  Future<void> _createModuleIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX subject_module_name ON subject_modules(subject,ifnull(parent_id,''),name COLLATE NOCASE)",
    );
    await customStatement(
      'CREATE INDEX knowledge_module_lookup ON knowledge_module_links(module_id,knowledge_id)',
    );
    await customStatement(
      'CREATE INDEX mistake_module_lookup ON mistake_module_links(module_id,mistake_id)',
    );
  }

  Future<void> _createExamIndexes() async {
    await customStatement('CREATE INDEX exam_event_date ON exam_events(date)');
    await customStatement(
      'CREATE INDEX exam_rows_subject ON exam_score_rows(subject_id,position)',
    );
    await customStatement(
      'CREATE INDEX exam_photos_subject ON exam_attachments(subject_id,created_at)',
    );
  }

  Future<void> _createPracticeLinkIndex() async {
    await customStatement(
      'CREATE INDEX practice_chat_message ON practice_chat_links(message_id)',
    );
  }

  Future<void> _createReviewIndexes() async {
    await customStatement(
      'CREATE INDEX review_due ON review_schedules(enabled, due_at)',
    );
    await customStatement(
      'CREATE INDEX review_history ON review_records(schedule_id, recorded_at)',
    );
  }

  Future<void> _createPracticeIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX one_pending_attempt ON practice_attempts(question_id) WHERE status IN ('draft','awaiting_self_grade')",
    );
    await customStatement(
      'CREATE INDEX attempts_question_time ON practice_attempts(question_id, started_at)',
    );
    await customStatement(
      'CREATE INDEX questions_source ON practice_questions(source_message_id, deleted)',
    );
    await customStatement(
      'CREATE INDEX questions_subject ON practice_questions(deleted, subject, created_at)',
    );
    await customStatement(
      'CREATE INDEX question_topic_lookup ON practice_question_topics(topic_id)',
    );
  }

  Future<void> _createStudyIndexes() async {
    await customStatement(
      'CREATE INDEX knowledge_subject_updated ON knowledge_items(deleted, subject, updated_at)',
    );
    await customStatement(
      'CREATE INDEX mistakes_subject_updated ON mistakes(deleted, subject, updated_at)',
    );
    await customStatement(
      'CREATE INDEX study_attachments_knowledge ON study_attachments(knowledge_id)',
    );
    await customStatement(
      'CREATE INDEX study_attachments_mistake ON study_attachments(mistake_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX tool_write_dedup ON ai_tool_operations(run_id, name, arguments) WHERE name IN ('create_knowledge','update_knowledge','delete_knowledge','create_mistake','update_mistake','delete_mistake','link_mistake_to_knowledge','schedule_review') AND status IN ('pending','running','succeeded')",
    );
    for (final (table, fts, content) in [
      ('knowledge_items', 'knowledge_search', 'title, content, chapter'),
      (
        'mistakes',
        'mistake_search',
        'title, question, chapter, correct_answer, original_answer, own_analysis, ai_analysis, error_reason, suggested_reason',
      ),
    ]) {
      final names = content.split(', ');
      final newValues = names.map((n) => 'new.$n').join(', ');
      final oldValues = names.map((n) => 'old.$n').join(', ');
      await customStatement(
        "CREATE VIRTUAL TABLE $fts USING fts5($content, content='$table', content_rowid='rowid', tokenize='trigram')",
      );
      await customStatement(
        'CREATE TRIGGER ${fts}_ai AFTER INSERT ON $table BEGIN INSERT INTO $fts(rowid, $content) VALUES(new.rowid, $newValues); END',
      );
      await customStatement(
        "CREATE TRIGGER ${fts}_ad AFTER DELETE ON $table BEGIN INSERT INTO $fts($fts, rowid, $content) VALUES('delete', old.rowid, $oldValues); END",
      );
      await customStatement(
        "CREATE TRIGGER ${fts}_au AFTER UPDATE ON $table BEGIN INSERT INTO $fts($fts, rowid, $content) VALUES('delete', old.rowid, $oldValues); INSERT INTO $fts(rowid, $content) VALUES(new.rowid, $newValues); END",
      );
    }
  }

  Future<List<ChatSession>> sessions([String query = '']) async {
    final rows =
        await (select(chatSessions)
              ..where((s) => s.deleted.equals(false))
              ..orderBy([(s) => OrderingTerm.desc(s.updatedAt)]))
            .get();
    if (query.trim().isEmpty) return rows;
    // LIKE fallback handles short Chinese queries that FTS trigram cannot index.
    final term = query.trim();
    final ids = term.runes.length >= 3
        ? await customSelect(
            'SELECT DISTINCT session_id FROM message_search WHERE message_search MATCH ?',
            variables: [Variable('"${term.replaceAll('"', '""')}"')],
          ).get()
        : await customSelect(
            'SELECT DISTINCT session_id FROM chat_messages WHERE instr(lower(content), lower(?)) > 0',
            variables: [Variable(term)],
          ).get();
    final matched = ids.map((r) => r.read<String>('session_id')).toSet();
    return rows
        .where(
          (s) =>
              s.title.toLowerCase().contains(query.trim().toLowerCase()) ||
              matched.contains(s.id),
        )
        .toList();
  }

  Future<List<ChatSession>> trash() =>
      (select(chatSessions)..where((s) => s.deleted.equals(true))).get();
  Future<ChatSession> createSession({
    String title = '新的学习对话',
    String mode = 'guided',
    String? subject,
  }) async {
    if (!['guided', 'direct', 'exam'].contains(mode)) {
      throw const FormatException('教学模式无效。');
    }
    final id = const Uuid().v4();
    final now = DateTime.now();
    await into(chatSessions).insert(
      ChatSessionsCompanion.insert(
        id: id,
        title: title,
        mode: Value(mode),
        subject: Value(subject),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (select(chatSessions)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<List<ChatMessage>> messages(String session) =>
      (select(chatMessages)
            ..where((m) => m.sessionId.equals(session))
            ..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.rowId),
            ]))
          .get();
  Future<List<Attachment>> images(String session) =>
      (select(attachments)..where((a) => a.sessionId.equals(session))).get();
  Future<void> saveDraft(String id, String draft) =>
      (update(chatSessions)..where((s) => s.id.equals(id))).write(
        ChatSessionsCompanion(draft: Value(draft)),
      );
  Future<void> rename(String id, String title) async {
    if (title.trim().isEmpty) throw const FormatException('会话名称不能为空');
    await (update(chatSessions)..where((s) => s.id.equals(id))).write(
      ChatSessionsCompanion(
        title: Value(title.trim()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setSessionSubject(String id, String subject) async {
    await (update(chatSessions)..where((s) => s.id.equals(id))).write(
      ChatSessionsCompanion(subject: Value(subject)),
    );
  }

  Future<void> setDeleted(String id, bool deleted) async {
    await (update(chatSessions)..where((s) => s.id.equals(id))).write(
      ChatSessionsCompanion(deleted: Value(deleted)),
    );
  }

  Future<ProviderConfig> config() async {
    await into(providerConfigs).insert(
      const ProviderConfigsCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
    return select(providerConfigs).getSingle();
  }

  Future<void> saveConfig(ProviderConfig config) =>
      into(providerConfigs).insertOnConflictUpdate(config);
  Future<String?> preference(String name) async => (await (select(
    preferences,
  )..where((p) => p.name.equals(name))).getSingleOrNull())?.value;
  Future<void> setPreference(String name, String value) => into(preferences)
      .insertOnConflictUpdate(
        PreferencesCompanion.insert(name: name, value: value),
      );
}
