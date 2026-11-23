part of "database.dart";

class LanguagePromptSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class LanguageGenerationTasks extends Table {
  TextColumn get id => text()();
  TextColumn get feature => text()();
  TextColumn get activeRunId => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class LanguageGenerationRuns extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(LanguageGenerationTasks, #id)();
  TextColumn get promptId =>
      text().nullable().references(LanguagePromptSnapshots, #id)();
  TextColumn get inputJson => text()();
  TextColumn get provider => text().nullable()();
  TextColumn get endpoint => text().nullable()();
  TextColumn get model => text()();
  BoolColumn get thinking => boolean().nullable()();
  TextColumn get effort => text().nullable()();
  TextColumn get optionsJson => text()();
  TextColumn get output => text()();
  TextColumn get format => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class LanguageGenerationChoices extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(LanguageGenerationTasks, #id)();
  TextColumn get previousRunId =>
      text().nullable().references(LanguageGenerationRuns, #id)();
  TextColumn get candidateRunId =>
      text().references(LanguageGenerationRuns, #id)();
  TextColumn get chosenRunId =>
      text().references(LanguageGenerationRuns, #id)();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class LanguageGenerationLinks extends Table {
  TextColumn get kind => text()();
  TextColumn get contentId => text()();
  IntColumn get selectionOrder => integer()();
  TextColumn get runId => text().references(LanguageGenerationRuns, #id)();
  @override
  Set<Column> get primaryKey => {kind, contentId, runId};
}
