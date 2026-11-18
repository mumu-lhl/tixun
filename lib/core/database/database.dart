import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_error.dart';
import 'search_terms.dart';

part 'database.g.dart';
part 'study_tables.dart';
part 'practice_tables.dart';
part 'review_tables.dart';
part 'exam_tables.dart';
part 'module_tables.dart';
part 'visual_tables.dart';
part 'language_tables.dart';
part 'database_migrations.dart';

class ChatSessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get subject => text().nullable()();
  TextColumn get mode => text().withDefault(const Constant('guided'))();
  TextColumn get stage => text().withDefault(const Constant('diagnosing'))();
  BoolColumn get toolsEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get draft => text().withDefault(const Constant(''))();
  // Context compression state: the summary of older turns (persisted so
  // later sends reuse it) and the id of the last message it covers.
  TextColumn get contextSummary => text().nullable()();
  TextColumn get contextSummaryUpToId => text().nullable()();
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

/// Ordered model events attached to the visible message that owns them.
class ChatContextEvents extends Table {
  TextColumn get messageId =>
      text().references(ChatMessages, #id, onDelete: KeyAction.cascade)();
  IntColumn get sequence => integer()();
  TextColumn get inputMessageId => text().nullable().references(
    ChatMessages,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {messageId, sequence};
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

class AiUsageEvents extends Table {
  TextColumn get id => text()();
  TextColumn get actionId => text()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get messageId => text().nullable()();
  TextColumn get providerKind => text()();
  TextColumn get endpoint => text().withDefault(const Constant(''))();
  TextColumn get model => text()();
  TextColumn get feature => text()();
  TextColumn get status => text()();
  TextColumn get usageSource => text().withDefault(const Constant('unknown'))();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get imageCount => integer().withDefault(const Constant(0))();
  IntColumn get toolCallCount => integer().withDefault(const Constant(0))();
  IntColumn get inputTokens => integer().nullable()();
  IntColumn get cachedInputTokens => integer().nullable()();
  IntColumn get outputTokens => integer().nullable()();
  IntColumn get reasoningTokens => integer().nullable()();
  IntColumn get totalTokens => integer().nullable()();
  TextColumn get tokenBreakdownJson => text().nullable()();
  IntColumn get costNanoUsd => integer().nullable()();
  TextColumn get costBasis => text().withDefault(const Constant('unknown'))();
  IntColumn get inputRateNanoUsdPerMillion => integer().nullable()();
  IntColumn get cachedInputRateNanoUsdPerMillion => integer().nullable()();
  IntColumn get outputRateNanoUsdPerMillion => integer().nullable()();
  TextColumn get rateSource => text().nullable()();
  DateTimeColumn get rateUpdatedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class AiModelPrices extends Table {
  TextColumn get providerKind => text()();
  TextColumn get endpoint => text().withDefault(const Constant(''))();
  TextColumn get model => text()();
  IntColumn get inputRateNanoUsdPerMillion => integer()();
  IntColumn get cachedInputRateNanoUsdPerMillion => integer()();
  IntColumn get outputRateNanoUsdPerMillion => integer()();
  IntColumn get offPeakDiscountPercent =>
      integer().withDefault(const Constant(0))();
  TextColumn get source => text().withDefault(const Constant('user'))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {providerKind, endpoint, model};
}

@DriftDatabase(
  tables: [
    ChatSessions,
    ChatMessages,
    ChatContextEvents,
    Attachments,
    ProviderConfigs,
    Preferences,
    AiUsageEvents,
    AiModelPrices,
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
    TimelineEvents,
    ExamSubjects,
    ExamScoreRows,
    ExamAttachments,
    SubjectModules,
    KnowledgeModuleLinks,
    MistakeModuleLinks,
    VisualScenes,
    VisualSceneRevisions,
    VisualMessageLinks,
    VisualQuestionLinks,
    VisualStudyLinks,
    LearningLexicalItems,
    LearningLexicalSenses,
    LearningVocabularyGroups,
    LearningGroupItems,
    LearningEvidence,
    LearningReviewSchedules,
    LearningSentenceBatches,
    LearningSentenceAttempts,
    LearningInlineExplanations,
    LearningWritingDrafts,
    LearningWritingVersions,
    LearningWritingEvaluations,
    LearningWritingNotes,
    LearningExamMaterials,
    LearningExamAttempts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);
  factory AppDatabase.file(File file) =>
      AppDatabase(NativeDatabase.createInBackground(file));
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());
  static const latestSchemaVersion = 23;
  @override
  int get schemaVersion => latestSchemaVersion;
  @override
  MigrationStrategy get migration => _migrationStrategy;

  Future<List<ChatSession>> sessions([
    String query = '',
    String subject = '',
  ]) async {
    final term = query.trim();
    final variables = <Variable>[];
    var where = 's.deleted = 0';
    if (subject.isNotEmpty) {
      where += ' AND s.subject = ?';
      variables.add(Variable(subject));
    }
    for (final keyword in searchTerms(term)) {
      final messageMatch = keyword.runes.length >= 3
          ? 'SELECT session_id FROM message_search WHERE message_search MATCH ?'
          : 'SELECT session_id FROM chat_messages WHERE instr(lower(content), lower(?)) > 0';
      where +=
          ' AND (instr(lower(s.title), lower(?)) > 0 OR s.id IN ($messageMatch))';
      variables.add(Variable(keyword));
      variables.add(
        Variable(
          keyword.runes.length >= 3
              ? '"${keyword.replaceAll('"', '""')}"'
              : keyword,
        ),
      );
    }
    // updated_at is stored with second precision, so two sends inside the
    // same second tie. Break the tie with the latest message's rowid, which
    // grows with every insert and therefore tracks the newest activity.
    const activityTieBreak =
        '(SELECT MAX(rowid) FROM chat_messages WHERE session_id = s.id) DESC';
    final order = term.isEmpty
        ? 's.updated_at DESC, $activityTieBreak, s.id'
        : 'CASE WHEN instr(lower(s.title), lower(?)) > 0 THEN 0 ELSE 1 END, s.updated_at DESC, $activityTieBreak, s.id';
    if (term.isNotEmpty) variables.add(Variable(searchTerms(term).join(' ')));
    final rows = await customSelect(
      'SELECT s.* FROM chat_sessions s WHERE $where ORDER BY $order',
      variables: variables,
      readsFrom: {chatSessions, chatMessages},
    ).get();
    return Future.wait(rows.map(chatSessions.mapFromRow));
  }

  Future<ChatMessage?> matchingMessage(String sessionId, String query) async {
    final terms = searchTerms(query);
    if (terms.isEmpty) return null;
    final rows = await customSelect(
      'SELECT * FROM chat_messages WHERE session_id = ? AND (${List.filled(terms.length, 'instr(lower(content), lower(?)) > 0').join(' OR ')}) ORDER BY ${List.filled(terms.length, '(instr(lower(content), lower(?)) > 0)').join(' + ')} DESC, created_at DESC LIMIT 1',
      variables: [
        Variable(sessionId),
        ...terms.map(Variable.new),
        ...terms.map(Variable.new),
      ],
      readsFrom: {chatMessages},
    ).get();
    return rows.isEmpty ? null : chatMessages.mapFromRow(rows.first);
  }

  Future<List<ChatSession>> trash() =>
      (select(chatSessions)..where((s) => s.deleted.equals(true))).get();
  Future<ChatSession> createSession({
    String title = '新的学习对话',
    String mode = 'guided',
    String? subject,
  }) async {
    if (!['guided', 'direct', 'exam'].contains(mode)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidTeachingMode,
        '教学模式无效。',
      );
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
    if (title.trim().isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorTheConversationNameCannotBeEmpty,
        '会话名称不能为空',
      );
    }
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

  Future<void> setContextSummary(String id, String? summary, String? upToId) =>
      (update(chatSessions)..where((s) => s.id.equals(id))).write(
        ChatSessionsCompanion(
          contextSummary: Value(summary),
          contextSummaryUpToId: Value(upToId),
        ),
      );

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
