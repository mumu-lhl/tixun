part of "database.dart";

class LanguageQuickActions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get description => text()();
  TextColumn get inputHint => text()();
  TextColumn get prompt => text()();
  TextColumn get sourceLanguage => text()();
  TextColumn get targetLanguage => text()();
  TextColumn get glossLanguage => text()();
  BoolColumn get detailed => boolean()();
  IntColumn get position => integer()();
  BoolColumn get builtIn => boolean()();
  BoolColumn get enabled => boolean()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LanguageQuickLookups extends Table {
  TextColumn get id => text()();
  TextColumn get actionId => text().references(LanguageQuickActions, #id)();
  TextColumn get actionName => text()();
  TextColumn get prompt => text()();
  TextColumn get promptSnapshotId =>
      text().nullable().references(LanguagePromptSnapshots, #id)();
  IntColumn get actionRevision => integer()();
  IntColumn get schemaRevision => integer()();
  TextColumn get input => text()();
  TextColumn get sourceLanguage => text()();
  TextColumn get targetLanguage => text()();
  TextColumn get glossLanguage => text()();
  TextColumn get level => text()();
  BoolColumn get detailed => boolean()();
  TextColumn get summary => text()();
  TextColumn get content => text()();
  TextColumn get candidates => text()();
  TextColumn get provider => text()();
  TextColumn get model => text()();
  TextColumn get cacheKey => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LanguageQuickLearningLinks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get lookupId => text().references(
    LanguageQuickLookups,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get senseId => text().nullable().references(
    LearningLexicalSenses,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get sentenceBatchId => text().nullable().references(
    LearningSentenceBatches,
    #id,
    onDelete: KeyAction.cascade,
  )();

  @override
  List<Set<Column>> get uniqueKeys => [
    {lookupId, senseId},
    {lookupId, sentenceBatchId},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK ((sense_id IS NULL) <> (sentence_batch_id IS NULL))",
  ];
}
