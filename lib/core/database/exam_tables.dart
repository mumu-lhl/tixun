part of 'database.dart';

class ExamEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class ExamSubjects extends Table {
  TextColumn get id => text()();
  TextColumn get eventId =>
      text().references(ExamEvents, #id, onDelete: KeyAction.cascade)();
  TextColumn get subject => text()();
  RealColumn get rawScore => real().nullable()();
  RealColumn get scaledScore => real().nullable()();
  RealColumn get maximum => real().nullable()();
  IntColumn get scoreRevision => integer().withDefault(const Constant(0))();
  TextColumn get aiReasoning => text().withDefault(const Constant(''))();
  TextColumn get aiModel => text().nullable()();
  BoolColumn get usesScaling => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {eventId, subject},
  ];
}

class ExamScoreRows extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId =>
      text().references(ExamSubjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get parentId => text().nullable().references(
    ExamScoreRows,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  TextColumn get label => text()();
  RealColumn get earned => real().nullable()();
  RealColumn get maximum => real().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

class ExamAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId =>
      text().references(ExamSubjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()();
  TextColumn get relativePath => text()();
  TextColumn get originalPath => text().nullable()();
  TextColumn get mime => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
