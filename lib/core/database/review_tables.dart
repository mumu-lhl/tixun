part of 'database.dart';

class ReviewSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get questionId => text().unique().references(
    PracticeQuestions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  RealColumn get ease => real().withDefault(const Constant(2.5))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class ReviewRecords extends Table {
  TextColumn get id => text()();
  TextColumn get scheduleId =>
      text().references(ReviewSchedules, #id, onDelete: KeyAction.cascade)();
  TextColumn get attemptId => text().nullable().references(
    PracticeAttempts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get event => text()();
  DateTimeColumn get previousDueAt => dateTime()();
  DateTimeColumn get nextDueAt => dateTime()();
  IntColumn get quality => integer().nullable()();
  BoolColumn get independent => boolean().withDefault(const Constant(false))();
  TextColumn get reason => text()();
  DateTimeColumn get recordedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<Set<Column>> get uniqueKeys => [
    {scheduleId, attemptId},
  ];
}
