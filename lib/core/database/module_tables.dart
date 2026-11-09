part of 'database.dart';

class SubjectModules extends Table {
  TextColumn get id => text()();
  TextColumn get subject => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable().references(
    SubjectModules,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class KnowledgeModuleLinks extends Table {
  TextColumn get knowledgeId =>
      text().references(KnowledgeItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get moduleId =>
      text().references(SubjectModules, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {knowledgeId, moduleId};
}

class MistakeModuleLinks extends Table {
  TextColumn get mistakeId =>
      text().references(Mistakes, #id, onDelete: KeyAction.cascade)();
  TextColumn get moduleId =>
      text().references(SubjectModules, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {mistakeId, moduleId};
}
