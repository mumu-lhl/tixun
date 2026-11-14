part of 'database.dart';

/// A saved Visual DSL scene (see `tixun-visual-dsl-v1.md`).
///
/// The scene itself is stored as JSON text; the store only persists it,
/// validation lives in the validator slice. `revision` counts the
/// snapshots in [VisualSceneRevisions]: every revision of a scene has one
/// immutable snapshot row, so a quiz question can reference
/// (`visualId`, `revision`) without later edits changing its figure.
///
/// The row class is [StoredVisualScene], not `VisualScene`: that name is
/// the DSL model type in `lib/core/visual/model/visual_scene.dart`, and
/// the tool/UI slices need both without import aliases.
@DataClassName('StoredVisualScene')
class VisualScenes extends Table {
  TextColumn get id => text()();
  TextColumn get sceneJson => text()();
  TextColumn get title => text().nullable()();
  IntColumn get dslVersion => integer().withDefault(const Constant(1))();
  TextColumn get verificationStatus =>
      text().withDefault(const Constant('unverified'))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get source => text().withDefault(const Constant('ai'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

/// Immutable snapshot of a scene at one revision (pattern copied from
/// [KnowledgeRevisions]).
class VisualSceneRevisions extends Table {
  TextColumn get visualId =>
      text().references(VisualScenes, #id, onDelete: KeyAction.cascade)();
  IntColumn get revision => integer()();
  TextColumn get sceneJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {visualId, revision};
}

class VisualMessageLinks extends Table {
  TextColumn get visualId =>
      text().references(VisualScenes, #id, onDelete: KeyAction.cascade)();
  TextColumn get messageId =>
      text().references(ChatMessages, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {visualId, messageId};
}

class VisualQuestionLinks extends Table {
  TextColumn get visualId =>
      text().references(VisualScenes, #id, onDelete: KeyAction.cascade)();
  TextColumn get questionId =>
      text().references(PracticeQuestions, #id, onDelete: KeyAction.cascade)();

  /// The pinned snapshot revision the question shows. A question never
  /// follows later edits: its figure is frozen at the revision recorded
  /// here (see `VisualStore.snapshotForQuestion`).
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {visualId, questionId};
}

/// A scene linked to exactly one study owner: a knowledge item or a
/// mistake (CHECK pattern copied from [StudyAttachments]).
class VisualStudyLinks extends Table {
  TextColumn get visualId =>
      text().references(VisualScenes, #id, onDelete: KeyAction.cascade)();
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
  Set<Column> get primaryKey => {visualId, knowledgeId, mistakeId};
  @override
  List<String> get customConstraints => [
    'CHECK ((knowledge_id IS NULL) <> (mistake_id IS NULL))',
  ];
}
