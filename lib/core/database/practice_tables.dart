part of 'database.dart';

class LearningTopics extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get subject => text()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {name, subject},
  ];
}

class PracticeQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get stem => text()();
  TextColumn get subject => text()();
  TextColumn get explanation => text().withDefault(const Constant(''))();
  TextColumn get hint => text().withDefault(const Constant(''))();
  TextColumn get origin => text()();
  TextColumn get verification =>
      text().withDefault(const Constant('unverified'))();
  RealColumn get absoluteTolerance =>
      real().withDefault(const Constant(0.000001))();
  RealColumn get relativeTolerance => real().withDefault(const Constant(0))();
  BoolColumn get caseSensitive => boolean().withDefault(const Constant(true))();
  IntColumn get timeLimitSeconds => integer().nullable()();
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
  TextColumn get sourceOperation => text().nullable().unique()();
  TextColumn get mistakeId => text().nullable().references(
    Mistakes,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get parentQuestionId => text().nullable().references(
    PracticeQuestions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class PracticeOptions extends Table {
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get optionId => text()();
  TextColumn get content => text()();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {questionId, optionId};
}

class PracticeAnswerKeys extends Table {
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get answer => text()();
  @override
  Set<Column> get primaryKey => {questionId, position, answer};
}

class PracticeQuestionTopics extends Table {
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get topicId =>
      text().references(LearningTopics, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {questionId, topicId};
}

class PracticeQuestionKnowledge extends Table {
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get knowledgeId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {questionId, knowledgeId};
}

class PracticeAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  BoolColumn get hintUsed => boolean().withDefault(const Constant(false))();
  BoolColumn get correct => boolean().nullable()();
  RealColumn get score => real().nullable()();
  TextColumn get gradingBasis => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get submittedAt => dateTime().nullable()();
  IntColumn get elapsedMilliseconds => integer().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class PracticeResponses extends Table {
  TextColumn get attemptId =>
      text().references(PracticeAttempts, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get answer => text()();
  @override
  Set<Column> get primaryKey => {attemptId, position};
}

class PracticeImages extends Table {
  TextColumn get id => text()();
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get relativePath => text()();
  TextColumn get mime => text()();
  IntColumn get byteLength => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A question can appear in several edited conversation branches without
/// duplicating the question itself or its attempts.
class PracticeChatLinks extends Table {
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();
  TextColumn get messageId =>
      text().references(ChatMessages, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {questionId, messageId};
}
