part of "database.dart";

/// An immutable layout revision. Branches copy the revision and keep its URL,
/// but each branch maintains its own renderer state.
@DataClassName("ChatA2uiSurface")
class ChatA2uiSurfaces extends Table {
  TextColumn get sessionId =>
      text().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().references(ChatMessages, #id, onDelete: KeyAction.cascade)();
  // Keeps the v29 column name. Inline blocks use a host-owned ordinal key.
  TextColumn get toolCallId => text()();
  TextColumn get protocol => text()();
  TextColumn get catalog => text()();
  TextColumn get express => text()();
  TextColumn get messagesJson => text()();
  TextColumn get stateJson => text().nullable()();
  IntColumn get autoOffset => integer().nullable()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column> get primaryKey => {sessionId, id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {messageId, toolCallId},
    {messageId, ordinal},
  ];
}

@DataClassName("ChatA2uiAction")
class ChatA2uiActions extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get surfaceId => text()();
  TextColumn get componentId => text()();
  TextColumn get kind => text()();
  TextColumn get contextJson => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "FOREIGN KEY (session_id, surface_id) REFERENCES chat_a2ui_surfaces(session_id, id) ON DELETE CASCADE",
  ];
}
