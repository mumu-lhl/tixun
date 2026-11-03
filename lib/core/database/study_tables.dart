part of 'database.dart';

class KnowledgeItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get subject => text()();
  TextColumn get kind => text().withDefault(const Constant('个人笔记'))();
  TextColumn get chapter => text().withDefault(const Constant(''))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get sourceSessionId => text().nullable().references(
    ChatSessions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get sourceMessageId => text().nullable().references(
    ChatMessages,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class KnowledgeRevisions extends Table {
  TextColumn get knowledgeId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get revision => integer()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get subject => text()();
  TextColumn get kind => text()();
  TextColumn get chapter => text()();
  TextColumn get tagsSnapshot => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {knowledgeId, revision};
}

class Mistakes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get question => text().withDefault(const Constant(''))();
  TextColumn get subject => text()();
  TextColumn get chapter => text().withDefault(const Constant(''))();
  TextColumn get correctAnswer => text().withDefault(const Constant(''))();
  TextColumn get originalAnswer => text().withDefault(const Constant(''))();
  TextColumn get ownAnalysis => text().withDefault(const Constant(''))();
  TextColumn get aiAnalysis => text().withDefault(const Constant(''))();
  TextColumn get errorReason => text().withDefault(const Constant('暂未确定'))();
  TextColumn get suggestedReason => text().withDefault(const Constant(''))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get sourceSessionId => text().nullable().references(
    ChatSessions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get sourceMessageId => text().nullable().references(
    ChatMessages,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class KnowledgeTags extends Table {
  TextColumn get knowledgeId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text()();
  @override
  Set<Column> get primaryKey => {knowledgeId, tag};
}

class MistakeTags extends Table {
  TextColumn get mistakeId =>
      text().references(Mistakes, #id, onDelete: KeyAction.cascade)();
  TextColumn get tag => text()();
  @override
  Set<Column> get primaryKey => {mistakeId, tag};
}

class KnowledgeRelations extends Table {
  @ReferenceName('outgoingKnowledgeRelations')
  TextColumn get sourceId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('incomingKnowledgeRelations')
  TextColumn get targetId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {sourceId, targetId};
  @override
  List<String> get customConstraints => ['CHECK (source_id <> target_id)'];
}

class MistakeKnowledgeLinks extends Table {
  TextColumn get mistakeId =>
      text().references(Mistakes, #id, onDelete: KeyAction.cascade)();
  TextColumn get knowledgeId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {mistakeId, knowledgeId};
}

class StudyAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get knowledgeId => text().nullable().references(
    KnowledgeItems,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get mistakeId => text().nullable().references(
    Mistakes,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get relativePath => text()();
  TextColumn get mime => text()();
  IntColumn get byteLength => integer()();
  TextColumn get parentId =>
      text().nullable().references(StudyAttachments, #id)();
  TextColumn get role => text().withDefault(const Constant('original'))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    'CHECK ((knowledge_id IS NULL) <> (mistake_id IS NULL))',
  ];
}

class AiToolOperations extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text()();
  TextColumn get sessionId => text().references(ChatSessions, #id)();
  TextColumn get name => text()();
  TextColumn get arguments => text()();
  TextColumn get status => text()();
  TextColumn get result => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class StudyChatLinks extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get knowledgeId => text().nullable().references(
    KnowledgeItems,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get mistakeId => text().nullable().references(
    Mistakes,
    #id,
    onDelete: KeyAction.cascade,
  )();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {sessionId, knowledgeId},
    {sessionId, mistakeId},
  ];
  @override
  List<String> get customConstraints => [
    'CHECK ((knowledge_id IS NULL) <> (mistake_id IS NULL))',
  ];
}
