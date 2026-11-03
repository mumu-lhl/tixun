import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get mode => text().withDefault(const Constant('guided'))();
  TextColumn get stage => text().withDefault(const Constant('diagnosing'))();
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
  IntColumn get totalTokens => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
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
  BoolColumn get thinking => boolean().withDefault(const Constant(false))();
  BoolColumn get supportsThinking =>
      boolean().withDefault(const Constant(true))();
  TextColumn get effort => text().withDefault(const Constant('high'))();
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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  factory AppDatabase.file(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
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
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
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
  Future<ChatSession> createSession({String title = '新的学习对话'}) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await into(chatSessions).insert(
      ChatSessionsCompanion.insert(
        id: id,
        title: title,
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
