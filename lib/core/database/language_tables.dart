part of 'database.dart';

class LearningLexicalItems extends Table {
  TextColumn get id => text()();
  TextColumn get language => text()();
  TextColumn get form => text()();
  TextColumn get normalizedForm => text()();
  TextColumn get lexicalType => text().withDefault(const Constant('word'))();
  TextColumn get pronunciation => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {language, normalizedForm, lexicalType},
  ];
}

class LearningLexicalSenses extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text().references(
    LearningLexicalItems,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get meaning => text()();
  TextColumn get partOfSpeech => text().nullable()();
  TextColumn get example => text().nullable()();
  TextColumn get exampleTranslation => text().nullable()();
  TextColumn get application => text().nullable()();
  TextColumn get applicationAnswer => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('user'))();
  TextColumn get aiBatchId => text().nullable()();
  TextColumn get aiModel => text().nullable()();
  IntColumn get aiPromptVersion => integer().nullable()();
  DateTimeColumn get aiGeneratedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, meaning},
  ];
}

class LearningVocabularyGroups extends Table {
  TextColumn get id => text()();
  TextColumn get language => text()();
  TextColumn get title => text()();
  TextColumn get groupType => text().withDefault(const Constant('topic'))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {language, title},
  ];
}

class LearningGroupItems extends Table {
  TextColumn get groupId => text().references(
    LearningVocabularyGroups,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get senseId => text().references(
    LearningLexicalSenses,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {groupId, senseId};
}

class LearningEvidence extends Table {
  TextColumn get id => text()();
  TextColumn get senseId => text().references(
    LearningLexicalSenses,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get skill => text()();
  TextColumn get rating => text().nullable()();
  TextColumn get answer => text().nullable()();
  BoolColumn get correct => boolean().nullable()();
  BoolColumn get answerRevealed =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get groupPrompt => boolean().withDefault(const Constant(false))();
  DateTimeColumn get occurredAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class LearningReviewSchedules extends Table {
  TextColumn get senseId => text().references(
    LearningLexicalSenses,
    #id,
    onDelete: KeyAction.cascade,
  )();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {senseId};
}

@DataClassName('LearningSentenceBatch')
class LearningSentenceBatches extends Table {
  TextColumn get id => text()();
  TextColumn get language => text()();
  TextColumn get topic => text()();
  TextColumn get style => text()();
  TextColumn get glossLanguage => text()();
  TextColumn get model => text()();
  IntColumn get promptVersion => integer()();
  BoolColumn get isMock => boolean()();
  TextColumn get cards => text()();
  DateTimeColumn get generatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LearningSentenceAttempts extends Table {
  TextColumn get id => text()();
  TextColumn get batchId => text()();
  TextColumn get sentenceId => text()();
  IntColumn get revision => integer()();
  TextColumn get language => text()();
  TextColumn get sentence => text()();
  TextColumn get skill => text()();
  TextColumn get rating => text()();
  TextColumn get answer => text().nullable()();
  BoolColumn get correct => boolean().nullable()();
  IntColumn get helpBeforeAnswer => integer().nullable()();
  IntColumn get helpUsed => integer()();
  DateTimeColumn get occurredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LearningInlineExplanations extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get contentId => text()();
  IntColumn get revision => integer()();
  TextColumn get model => text()();
  IntColumn get promptVersion => integer()();
  TextColumn get explanation => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}

class LearningWritingDrafts extends Table {
  TextColumn get taskId => text()();
  TextColumn get content => text()();

  @override
  Set<Column> get primaryKey => {taskId};
}

class LearningWritingVersions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LearningWritingEvaluations extends Table {
  TextColumn get versionId => text().references(
    LearningWritingVersions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get model => text()();
  IntColumn get promptVersion => integer()();
  BoolColumn get isMock => boolean()();
  IntColumn get taskScore => integer()();
  IntColumn get organizationScore => integer()();
  IntColumn get languageScore => integer()();
  TextColumn get summary => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {versionId};
}

class LearningWritingNotes extends Table {
  TextColumn get versionId => text().references(
    LearningWritingEvaluations,
    #versionId,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get kind => text()();
  TextColumn get comment => text()();

  @override
  Set<Column> get primaryKey => {versionId, position};
}
