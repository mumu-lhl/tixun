// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ChatSessionsTable extends ChatSessions
    with TableInfo<$ChatSessionsTable, ChatSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('guided'),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('diagnosing'),
  );
  static const VerificationMeta _toolsEnabledMeta = const VerificationMeta(
    'toolsEnabled',
  );
  @override
  late final GeneratedColumn<bool> toolsEnabled = GeneratedColumn<bool>(
    'tools_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tools_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _draftMeta = const VerificationMeta('draft');
  @override
  late final GeneratedColumn<String> draft = GeneratedColumn<String>(
    'draft',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    mode,
    stage,
    toolsEnabled,
    draft,
    createdAt,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    }
    if (data.containsKey('tools_enabled')) {
      context.handle(
        _toolsEnabledMeta,
        toolsEnabled.isAcceptableOrUnknown(
          data['tools_enabled']!,
          _toolsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('draft')) {
      context.handle(
        _draftMeta,
        draft.isAcceptableOrUnknown(data['draft']!, _draftMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      toolsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tools_enabled'],
      )!,
      draft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $ChatSessionsTable createAlias(String alias) {
    return $ChatSessionsTable(attachedDatabase, alias);
  }
}

class ChatSession extends DataClass implements Insertable<ChatSession> {
  final String id;
  final String title;
  final String mode;
  final String stage;
  final bool toolsEnabled;
  final String draft;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  const ChatSession({
    required this.id,
    required this.title,
    required this.mode,
    required this.stage,
    required this.toolsEnabled,
    required this.draft,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['mode'] = Variable<String>(mode);
    map['stage'] = Variable<String>(stage);
    map['tools_enabled'] = Variable<bool>(toolsEnabled);
    map['draft'] = Variable<String>(draft);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  ChatSessionsCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsCompanion(
      id: Value(id),
      title: Value(title),
      mode: Value(mode),
      stage: Value(stage),
      toolsEnabled: Value(toolsEnabled),
      draft: Value(draft),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory ChatSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSession(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      mode: serializer.fromJson<String>(json['mode']),
      stage: serializer.fromJson<String>(json['stage']),
      toolsEnabled: serializer.fromJson<bool>(json['toolsEnabled']),
      draft: serializer.fromJson<String>(json['draft']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'mode': serializer.toJson<String>(mode),
      'stage': serializer.toJson<String>(stage),
      'toolsEnabled': serializer.toJson<bool>(toolsEnabled),
      'draft': serializer.toJson<String>(draft),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  ChatSession copyWith({
    String? id,
    String? title,
    String? mode,
    String? stage,
    bool? toolsEnabled,
    String? draft,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) => ChatSession(
    id: id ?? this.id,
    title: title ?? this.title,
    mode: mode ?? this.mode,
    stage: stage ?? this.stage,
    toolsEnabled: toolsEnabled ?? this.toolsEnabled,
    draft: draft ?? this.draft,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  ChatSession copyWithCompanion(ChatSessionsCompanion data) {
    return ChatSession(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      mode: data.mode.present ? data.mode.value : this.mode,
      stage: data.stage.present ? data.stage.value : this.stage,
      toolsEnabled: data.toolsEnabled.present
          ? data.toolsEnabled.value
          : this.toolsEnabled,
      draft: data.draft.present ? data.draft.value : this.draft,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSession(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mode: $mode, ')
          ..write('stage: $stage, ')
          ..write('toolsEnabled: $toolsEnabled, ')
          ..write('draft: $draft, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    mode,
    stage,
    toolsEnabled,
    draft,
    createdAt,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSession &&
          other.id == this.id &&
          other.title == this.title &&
          other.mode == this.mode &&
          other.stage == this.stage &&
          other.toolsEnabled == this.toolsEnabled &&
          other.draft == this.draft &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class ChatSessionsCompanion extends UpdateCompanion<ChatSession> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> mode;
  final Value<String> stage;
  final Value<bool> toolsEnabled;
  final Value<String> draft;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const ChatSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.mode = const Value.absent(),
    this.stage = const Value.absent(),
    this.toolsEnabled = const Value.absent(),
    this.draft = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSessionsCompanion.insert({
    required String id,
    required String title,
    this.mode = const Value.absent(),
    this.stage = const Value.absent(),
    this.toolsEnabled = const Value.absent(),
    this.draft = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChatSession> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? mode,
    Expression<String>? stage,
    Expression<bool>? toolsEnabled,
    Expression<String>? draft,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (mode != null) 'mode': mode,
      if (stage != null) 'stage': stage,
      if (toolsEnabled != null) 'tools_enabled': toolsEnabled,
      if (draft != null) 'draft': draft,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? mode,
    Value<String>? stage,
    Value<bool>? toolsEnabled,
    Value<String>? draft,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return ChatSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      mode: mode ?? this.mode,
      stage: stage ?? this.stage,
      toolsEnabled: toolsEnabled ?? this.toolsEnabled,
      draft: draft ?? this.draft,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (toolsEnabled.present) {
      map['tools_enabled'] = Variable<bool>(toolsEnabled.value);
    }
    if (draft.present) {
      map['draft'] = Variable<String>(draft.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mode: $mode, ')
          ..write('stage: $stage, ')
          ..write('toolsEnabled: $toolsEnabled, ')
          ..write('draft: $draft, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (role IN (\'user\',\'assistant\'))',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('complete'),
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalTokensMeta = const VerificationMeta(
    'totalTokens',
  );
  @override
  late final GeneratedColumn<int> totalTokens = GeneratedColumn<int>(
    'total_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    role,
    content,
    status,
    error,
    model,
    totalTokens,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('total_tokens')) {
      context.handle(
        _totalTokensMeta,
        totalTokens.isAcceptableOrUnknown(
          data['total_tokens']!,
          _totalTokensMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      totalTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_tokens'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final String status;
  final String? error;
  final String? model;
  final int? totalTokens;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.status,
    this.error,
    this.model,
    this.totalTokens,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || totalTokens != null) {
      map['total_tokens'] = Variable<int>(totalTokens);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      status: Value(status),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      totalTokens: totalTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(totalTokens),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      status: serializer.fromJson<String>(json['status']),
      error: serializer.fromJson<String?>(json['error']),
      model: serializer.fromJson<String?>(json['model']),
      totalTokens: serializer.fromJson<int?>(json['totalTokens']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'status': serializer.toJson<String>(status),
      'error': serializer.toJson<String?>(error),
      'model': serializer.toJson<String?>(model),
      'totalTokens': serializer.toJson<int?>(totalTokens),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    String? status,
    Value<String?> error = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<int?> totalTokens = const Value.absent(),
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role ?? this.role,
    content: content ?? this.content,
    status: status ?? this.status,
    error: error.present ? error.value : this.error,
    model: model.present ? model.value : this.model,
    totalTokens: totalTokens.present ? totalTokens.value : this.totalTokens,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      status: data.status.present ? data.status.value : this.status,
      error: data.error.present ? data.error.value : this.error,
      model: data.model.present ? data.model.value : this.model,
      totalTokens: data.totalTokens.present
          ? data.totalTokens.value
          : this.totalTokens,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('model: $model, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    role,
    content,
    status,
    error,
    model,
    totalTokens,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.status == this.status &&
          other.error == this.error &&
          other.model == this.model &&
          other.totalTokens == this.totalTokens &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> status;
  final Value<String?> error;
  final Value<String?> model;
  final Value<int?> totalTokens;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.model = const Value.absent(),
    this.totalTokens = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    this.status = const Value.absent(),
    this.error = const Value.absent(),
    this.model = const Value.absent(),
    this.totalTokens = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? status,
    Expression<String>? error,
    Expression<String>? model,
    Expression<int>? totalTokens,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (status != null) 'status': status,
      if (error != null) 'error': error,
      if (model != null) 'model': model,
      if (totalTokens != null) 'total_tokens': totalTokens,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? role,
    Value<String>? content,
    Value<String>? status,
    Value<String?>? error,
    Value<String?>? model,
    Value<int?>? totalTokens,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      status: status ?? this.status,
      error: error ?? this.error,
      model: model ?? this.model,
      totalTokens: totalTokens ?? this.totalTokens,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (totalTokens.present) {
      map['total_tokens'] = Variable<int>(totalTokens.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('status: $status, ')
          ..write('error: $error, ')
          ..write('model: $model, ')
          ..write('totalTokens: $totalTokens, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_messages (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalPathMeta = const VerificationMeta(
    'originalPath',
  );
  @override
  late final GeneratedColumn<String> originalPath = GeneratedColumn<String>(
    'original_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    messageId,
    relativePath,
    originalPath,
    mime,
    byteLength,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('original_path')) {
      context.handle(
        _originalPathMeta,
        originalPath.isAcceptableOrUnknown(
          data['original_path']!,
          _originalPathMeta,
        ),
      );
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      ),
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      originalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_path'],
      ),
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final String id;
  final String sessionId;
  final String? messageId;
  final String relativePath;
  final String? originalPath;
  final String mime;
  final int byteLength;
  const Attachment({
    required this.id,
    required this.sessionId,
    this.messageId,
    required this.relativePath,
    this.originalPath,
    required this.mime,
    required this.byteLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || messageId != null) {
      map['message_id'] = Variable<String>(messageId);
    }
    map['relative_path'] = Variable<String>(relativePath);
    if (!nullToAbsent || originalPath != null) {
      map['original_path'] = Variable<String>(originalPath);
    }
    map['mime'] = Variable<String>(mime);
    map['byte_length'] = Variable<int>(byteLength);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      messageId: messageId == null && nullToAbsent
          ? const Value.absent()
          : Value(messageId),
      relativePath: Value(relativePath),
      originalPath: originalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(originalPath),
      mime: Value(mime),
      byteLength: Value(byteLength),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      messageId: serializer.fromJson<String?>(json['messageId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      originalPath: serializer.fromJson<String?>(json['originalPath']),
      mime: serializer.fromJson<String>(json['mime']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'messageId': serializer.toJson<String?>(messageId),
      'relativePath': serializer.toJson<String>(relativePath),
      'originalPath': serializer.toJson<String?>(originalPath),
      'mime': serializer.toJson<String>(mime),
      'byteLength': serializer.toJson<int>(byteLength),
    };
  }

  Attachment copyWith({
    String? id,
    String? sessionId,
    Value<String?> messageId = const Value.absent(),
    String? relativePath,
    Value<String?> originalPath = const Value.absent(),
    String? mime,
    int? byteLength,
  }) => Attachment(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    messageId: messageId.present ? messageId.value : this.messageId,
    relativePath: relativePath ?? this.relativePath,
    originalPath: originalPath.present ? originalPath.value : this.originalPath,
    mime: mime ?? this.mime,
    byteLength: byteLength ?? this.byteLength,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      originalPath: data.originalPath.present
          ? data.originalPath.value
          : this.originalPath,
      mime: data.mime.present ? data.mime.value : this.mime,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('relativePath: $relativePath, ')
          ..write('originalPath: $originalPath, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    messageId,
    relativePath,
    originalPath,
    mime,
    byteLength,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.messageId == this.messageId &&
          other.relativePath == this.relativePath &&
          other.originalPath == this.originalPath &&
          other.mime == this.mime &&
          other.byteLength == this.byteLength);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> messageId;
  final Value<String> relativePath;
  final Value<String?> originalPath;
  final Value<String> mime;
  final Value<int> byteLength;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.originalPath = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String sessionId,
    this.messageId = const Value.absent(),
    required String relativePath,
    this.originalPath = const Value.absent(),
    required String mime,
    required int byteLength,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       relativePath = Value(relativePath),
       mime = Value(mime),
       byteLength = Value(byteLength);
  static Insertable<Attachment> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? messageId,
    Expression<String>? relativePath,
    Expression<String>? originalPath,
    Expression<String>? mime,
    Expression<int>? byteLength,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (messageId != null) 'message_id': messageId,
      if (relativePath != null) 'relative_path': relativePath,
      if (originalPath != null) 'original_path': originalPath,
      if (mime != null) 'mime': mime,
      if (byteLength != null) 'byte_length': byteLength,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String?>? messageId,
    Value<String>? relativePath,
    Value<String?>? originalPath,
    Value<String>? mime,
    Value<int>? byteLength,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      messageId: messageId ?? this.messageId,
      relativePath: relativePath ?? this.relativePath,
      originalPath: originalPath ?? this.originalPath,
      mime: mime ?? this.mime,
      byteLength: byteLength ?? this.byteLength,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (originalPath.present) {
      map['original_path'] = Variable<String>(originalPath.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('relativePath: $relativePath, ')
          ..write('originalPath: $originalPath, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderConfigsTable extends ProviderConfigs
    with TableInfo<$ProviderConfigsTable, ProviderConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('deepseek'),
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('https://api.deepseek.com'),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('deepseek-flash'),
  );
  static const VerificationMeta _visionMeta = const VerificationMeta('vision');
  @override
  late final GeneratedColumn<bool> vision = GeneratedColumn<bool>(
    'vision',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vision" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _supportsToolsMeta = const VerificationMeta(
    'supportsTools',
  );
  @override
  late final GeneratedColumn<bool> supportsTools = GeneratedColumn<bool>(
    'supports_tools',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_tools" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _thinkingMeta = const VerificationMeta(
    'thinking',
  );
  @override
  late final GeneratedColumn<bool> thinking = GeneratedColumn<bool>(
    'thinking',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("thinking" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportsThinkingMeta = const VerificationMeta(
    'supportsThinking',
  );
  @override
  late final GeneratedColumn<bool> supportsThinking = GeneratedColumn<bool>(
    'supports_thinking',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_thinking" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _effortMeta = const VerificationMeta('effort');
  @override
  late final GeneratedColumn<String> effort = GeneratedColumn<String>(
    'effort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('high'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    baseUrl,
    model,
    vision,
    supportsTools,
    thinking,
    supportsThinking,
    effort,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('vision')) {
      context.handle(
        _visionMeta,
        vision.isAcceptableOrUnknown(data['vision']!, _visionMeta),
      );
    }
    if (data.containsKey('supports_tools')) {
      context.handle(
        _supportsToolsMeta,
        supportsTools.isAcceptableOrUnknown(
          data['supports_tools']!,
          _supportsToolsMeta,
        ),
      );
    }
    if (data.containsKey('thinking')) {
      context.handle(
        _thinkingMeta,
        thinking.isAcceptableOrUnknown(data['thinking']!, _thinkingMeta),
      );
    }
    if (data.containsKey('supports_thinking')) {
      context.handle(
        _supportsThinkingMeta,
        supportsThinking.isAcceptableOrUnknown(
          data['supports_thinking']!,
          _supportsThinkingMeta,
        ),
      );
    }
    if (data.containsKey('effort')) {
      context.handle(
        _effortMeta,
        effort.isAcceptableOrUnknown(data['effort']!, _effortMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProviderConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      vision: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vision'],
      )!,
      supportsTools: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_tools'],
      )!,
      thinking: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}thinking'],
      )!,
      supportsThinking: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_thinking'],
      )!,
      effort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effort'],
      )!,
    );
  }

  @override
  $ProviderConfigsTable createAlias(String alias) {
    return $ProviderConfigsTable(attachedDatabase, alias);
  }
}

class ProviderConfig extends DataClass implements Insertable<ProviderConfig> {
  final int id;
  final String kind;
  final String baseUrl;
  final String model;
  final bool vision;
  final bool supportsTools;
  final bool thinking;
  final bool supportsThinking;
  final String effort;
  const ProviderConfig({
    required this.id,
    required this.kind,
    required this.baseUrl,
    required this.model,
    required this.vision,
    required this.supportsTools,
    required this.thinking,
    required this.supportsThinking,
    required this.effort,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['base_url'] = Variable<String>(baseUrl);
    map['model'] = Variable<String>(model);
    map['vision'] = Variable<bool>(vision);
    map['supports_tools'] = Variable<bool>(supportsTools);
    map['thinking'] = Variable<bool>(thinking);
    map['supports_thinking'] = Variable<bool>(supportsThinking);
    map['effort'] = Variable<String>(effort);
    return map;
  }

  ProviderConfigsCompanion toCompanion(bool nullToAbsent) {
    return ProviderConfigsCompanion(
      id: Value(id),
      kind: Value(kind),
      baseUrl: Value(baseUrl),
      model: Value(model),
      vision: Value(vision),
      supportsTools: Value(supportsTools),
      thinking: Value(thinking),
      supportsThinking: Value(supportsThinking),
      effort: Value(effort),
    );
  }

  factory ProviderConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderConfig(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      model: serializer.fromJson<String>(json['model']),
      vision: serializer.fromJson<bool>(json['vision']),
      supportsTools: serializer.fromJson<bool>(json['supportsTools']),
      thinking: serializer.fromJson<bool>(json['thinking']),
      supportsThinking: serializer.fromJson<bool>(json['supportsThinking']),
      effort: serializer.fromJson<String>(json['effort']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'model': serializer.toJson<String>(model),
      'vision': serializer.toJson<bool>(vision),
      'supportsTools': serializer.toJson<bool>(supportsTools),
      'thinking': serializer.toJson<bool>(thinking),
      'supportsThinking': serializer.toJson<bool>(supportsThinking),
      'effort': serializer.toJson<String>(effort),
    };
  }

  ProviderConfig copyWith({
    int? id,
    String? kind,
    String? baseUrl,
    String? model,
    bool? vision,
    bool? supportsTools,
    bool? thinking,
    bool? supportsThinking,
    String? effort,
  }) => ProviderConfig(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    vision: vision ?? this.vision,
    supportsTools: supportsTools ?? this.supportsTools,
    thinking: thinking ?? this.thinking,
    supportsThinking: supportsThinking ?? this.supportsThinking,
    effort: effort ?? this.effort,
  );
  ProviderConfig copyWithCompanion(ProviderConfigsCompanion data) {
    return ProviderConfig(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      model: data.model.present ? data.model.value : this.model,
      vision: data.vision.present ? data.vision.value : this.vision,
      supportsTools: data.supportsTools.present
          ? data.supportsTools.value
          : this.supportsTools,
      thinking: data.thinking.present ? data.thinking.value : this.thinking,
      supportsThinking: data.supportsThinking.present
          ? data.supportsThinking.value
          : this.supportsThinking,
      effort: data.effort.present ? data.effort.value : this.effort,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConfig(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('vision: $vision, ')
          ..write('supportsTools: $supportsTools, ')
          ..write('thinking: $thinking, ')
          ..write('supportsThinking: $supportsThinking, ')
          ..write('effort: $effort')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    baseUrl,
    model,
    vision,
    supportsTools,
    thinking,
    supportsThinking,
    effort,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderConfig &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.baseUrl == this.baseUrl &&
          other.model == this.model &&
          other.vision == this.vision &&
          other.supportsTools == this.supportsTools &&
          other.thinking == this.thinking &&
          other.supportsThinking == this.supportsThinking &&
          other.effort == this.effort);
}

class ProviderConfigsCompanion extends UpdateCompanion<ProviderConfig> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> baseUrl;
  final Value<String> model;
  final Value<bool> vision;
  final Value<bool> supportsTools;
  final Value<bool> thinking;
  final Value<bool> supportsThinking;
  final Value<String> effort;
  const ProviderConfigsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.vision = const Value.absent(),
    this.supportsTools = const Value.absent(),
    this.thinking = const Value.absent(),
    this.supportsThinking = const Value.absent(),
    this.effort = const Value.absent(),
  });
  ProviderConfigsCompanion.insert({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.model = const Value.absent(),
    this.vision = const Value.absent(),
    this.supportsTools = const Value.absent(),
    this.thinking = const Value.absent(),
    this.supportsThinking = const Value.absent(),
    this.effort = const Value.absent(),
  });
  static Insertable<ProviderConfig> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? baseUrl,
    Expression<String>? model,
    Expression<bool>? vision,
    Expression<bool>? supportsTools,
    Expression<bool>? thinking,
    Expression<bool>? supportsThinking,
    Expression<String>? effort,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (baseUrl != null) 'base_url': baseUrl,
      if (model != null) 'model': model,
      if (vision != null) 'vision': vision,
      if (supportsTools != null) 'supports_tools': supportsTools,
      if (thinking != null) 'thinking': thinking,
      if (supportsThinking != null) 'supports_thinking': supportsThinking,
      if (effort != null) 'effort': effort,
    });
  }

  ProviderConfigsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? baseUrl,
    Value<String>? model,
    Value<bool>? vision,
    Value<bool>? supportsTools,
    Value<bool>? thinking,
    Value<bool>? supportsThinking,
    Value<String>? effort,
  }) {
    return ProviderConfigsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      vision: vision ?? this.vision,
      supportsTools: supportsTools ?? this.supportsTools,
      thinking: thinking ?? this.thinking,
      supportsThinking: supportsThinking ?? this.supportsThinking,
      effort: effort ?? this.effort,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (vision.present) {
      map['vision'] = Variable<bool>(vision.value);
    }
    if (supportsTools.present) {
      map['supports_tools'] = Variable<bool>(supportsTools.value);
    }
    if (thinking.present) {
      map['thinking'] = Variable<bool>(thinking.value);
    }
    if (supportsThinking.present) {
      map['supports_thinking'] = Variable<bool>(supportsThinking.value);
    }
    if (effort.present) {
      map['effort'] = Variable<String>(effort.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderConfigsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('model: $model, ')
          ..write('vision: $vision, ')
          ..write('supportsTools: $supportsTools, ')
          ..write('thinking: $thinking, ')
          ..write('supportsThinking: $supportsThinking, ')
          ..write('effort: $effort')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  final String name;
  final String value;
  const Preference({required this.name, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(name: Value(name), value: Value(value));
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
    };
  }

  Preference copyWith({String? name, String? value}) =>
      Preference(name: name ?? this.name, value: value ?? this.value);
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('name: $name, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.name == this.name &&
          other.value == this.value);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<String> name;
  final Value<String> value;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String name,
    required String value,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value);
  static Insertable<Preference> custom({
    Expression<String>? name,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? name,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      name: name ?? this.name,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeItemsTable extends KnowledgeItems
    with TableInfo<$KnowledgeItemsTable, KnowledgeItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('个人笔记'),
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta(
    'chapter',
  );
  @override
  late final GeneratedColumn<String> chapter = GeneratedColumn<String>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sourceSessionIdMeta = const VerificationMeta(
    'sourceSessionId',
  );
  @override
  late final GeneratedColumn<String> sourceSessionId = GeneratedColumn<String>(
    'source_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_messages (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    subject,
    kind,
    chapter,
    revision,
    sourceSessionId,
    sourceMessageId,
    createdAt,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('chapter')) {
      context.handle(
        _chapterMeta,
        chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('source_session_id')) {
      context.handle(
        _sourceSessionIdMeta,
        sourceSessionId.isAcceptableOrUnknown(
          data['source_session_id']!,
          _sourceSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KnowledgeItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      sourceSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_session_id'],
      ),
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $KnowledgeItemsTable createAlias(String alias) {
    return $KnowledgeItemsTable(attachedDatabase, alias);
  }
}

class KnowledgeItem extends DataClass implements Insertable<KnowledgeItem> {
  final String id;
  final String title;
  final String content;
  final String subject;
  final String kind;
  final String chapter;
  final int revision;
  final String? sourceSessionId;
  final String? sourceMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  const KnowledgeItem({
    required this.id,
    required this.title,
    required this.content,
    required this.subject,
    required this.kind,
    required this.chapter,
    required this.revision,
    this.sourceSessionId,
    this.sourceMessageId,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['subject'] = Variable<String>(subject);
    map['kind'] = Variable<String>(kind);
    map['chapter'] = Variable<String>(chapter);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || sourceSessionId != null) {
      map['source_session_id'] = Variable<String>(sourceSessionId);
    }
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<String>(sourceMessageId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  KnowledgeItemsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeItemsCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      subject: Value(subject),
      kind: Value(kind),
      chapter: Value(chapter),
      revision: Value(revision),
      sourceSessionId: sourceSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSessionId),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory KnowledgeItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeItem(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      subject: serializer.fromJson<String>(json['subject']),
      kind: serializer.fromJson<String>(json['kind']),
      chapter: serializer.fromJson<String>(json['chapter']),
      revision: serializer.fromJson<int>(json['revision']),
      sourceSessionId: serializer.fromJson<String?>(json['sourceSessionId']),
      sourceMessageId: serializer.fromJson<String?>(json['sourceMessageId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'subject': serializer.toJson<String>(subject),
      'kind': serializer.toJson<String>(kind),
      'chapter': serializer.toJson<String>(chapter),
      'revision': serializer.toJson<int>(revision),
      'sourceSessionId': serializer.toJson<String?>(sourceSessionId),
      'sourceMessageId': serializer.toJson<String?>(sourceMessageId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  KnowledgeItem copyWith({
    String? id,
    String? title,
    String? content,
    String? subject,
    String? kind,
    String? chapter,
    int? revision,
    Value<String?> sourceSessionId = const Value.absent(),
    Value<String?> sourceMessageId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) => KnowledgeItem(
    id: id ?? this.id,
    title: title ?? this.title,
    content: content ?? this.content,
    subject: subject ?? this.subject,
    kind: kind ?? this.kind,
    chapter: chapter ?? this.chapter,
    revision: revision ?? this.revision,
    sourceSessionId: sourceSessionId.present
        ? sourceSessionId.value
        : this.sourceSessionId,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  KnowledgeItem copyWithCompanion(KnowledgeItemsCompanion data) {
    return KnowledgeItem(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      subject: data.subject.present ? data.subject.value : this.subject,
      kind: data.kind.present ? data.kind.value : this.kind,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      revision: data.revision.present ? data.revision.value : this.revision,
      sourceSessionId: data.sourceSessionId.present
          ? data.sourceSessionId.value
          : this.sourceSessionId,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeItem(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('subject: $subject, ')
          ..write('kind: $kind, ')
          ..write('chapter: $chapter, ')
          ..write('revision: $revision, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    subject,
    kind,
    chapter,
    revision,
    sourceSessionId,
    sourceMessageId,
    createdAt,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeItem &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.subject == this.subject &&
          other.kind == this.kind &&
          other.chapter == this.chapter &&
          other.revision == this.revision &&
          other.sourceSessionId == this.sourceSessionId &&
          other.sourceMessageId == this.sourceMessageId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class KnowledgeItemsCompanion extends UpdateCompanion<KnowledgeItem> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> content;
  final Value<String> subject;
  final Value<String> kind;
  final Value<String> chapter;
  final Value<int> revision;
  final Value<String?> sourceSessionId;
  final Value<String?> sourceMessageId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const KnowledgeItemsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.subject = const Value.absent(),
    this.kind = const Value.absent(),
    this.chapter = const Value.absent(),
    this.revision = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeItemsCompanion.insert({
    required String id,
    required String title,
    required String content,
    required String subject,
    this.kind = const Value.absent(),
    this.chapter = const Value.absent(),
    this.revision = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       content = Value(content),
       subject = Value(subject),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<KnowledgeItem> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? subject,
    Expression<String>? kind,
    Expression<String>? chapter,
    Expression<int>? revision,
    Expression<String>? sourceSessionId,
    Expression<String>? sourceMessageId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (subject != null) 'subject': subject,
      if (kind != null) 'kind': kind,
      if (chapter != null) 'chapter': chapter,
      if (revision != null) 'revision': revision,
      if (sourceSessionId != null) 'source_session_id': sourceSessionId,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? content,
    Value<String>? subject,
    Value<String>? kind,
    Value<String>? chapter,
    Value<int>? revision,
    Value<String?>? sourceSessionId,
    Value<String?>? sourceMessageId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return KnowledgeItemsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      kind: kind ?? this.kind,
      chapter: chapter ?? this.chapter,
      revision: revision ?? this.revision,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<String>(chapter.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (sourceSessionId.present) {
      map['source_session_id'] = Variable<String>(sourceSessionId.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeItemsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('subject: $subject, ')
          ..write('kind: $kind, ')
          ..write('chapter: $chapter, ')
          ..write('revision: $revision, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeRevisionsTable extends KnowledgeRevisions
    with TableInfo<$KnowledgeRevisionsTable, KnowledgeRevision> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _knowledgeIdMeta = const VerificationMeta(
    'knowledgeId',
  );
  @override
  late final GeneratedColumn<String> knowledgeId = GeneratedColumn<String>(
    'knowledge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta(
    'chapter',
  );
  @override
  late final GeneratedColumn<String> chapter = GeneratedColumn<String>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagsSnapshotMeta = const VerificationMeta(
    'tagsSnapshot',
  );
  @override
  late final GeneratedColumn<String> tagsSnapshot = GeneratedColumn<String>(
    'tags_snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    knowledgeId,
    revision,
    title,
    content,
    subject,
    kind,
    chapter,
    tagsSnapshot,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeRevision> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('knowledge_id')) {
      context.handle(
        _knowledgeIdMeta,
        knowledgeId.isAcceptableOrUnknown(
          data['knowledge_id']!,
          _knowledgeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_knowledgeIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('chapter')) {
      context.handle(
        _chapterMeta,
        chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterMeta);
    }
    if (data.containsKey('tags_snapshot')) {
      context.handle(
        _tagsSnapshotMeta,
        tagsSnapshot.isAcceptableOrUnknown(
          data['tags_snapshot']!,
          _tagsSnapshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tagsSnapshotMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {knowledgeId, revision};
  @override
  KnowledgeRevision map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeRevision(
      knowledgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter'],
      )!,
      tagsSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_snapshot'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $KnowledgeRevisionsTable createAlias(String alias) {
    return $KnowledgeRevisionsTable(attachedDatabase, alias);
  }
}

class KnowledgeRevision extends DataClass
    implements Insertable<KnowledgeRevision> {
  final String knowledgeId;
  final int revision;
  final String title;
  final String content;
  final String subject;
  final String kind;
  final String chapter;
  final String tagsSnapshot;
  final DateTime createdAt;
  const KnowledgeRevision({
    required this.knowledgeId,
    required this.revision,
    required this.title,
    required this.content,
    required this.subject,
    required this.kind,
    required this.chapter,
    required this.tagsSnapshot,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['knowledge_id'] = Variable<String>(knowledgeId);
    map['revision'] = Variable<int>(revision);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['subject'] = Variable<String>(subject);
    map['kind'] = Variable<String>(kind);
    map['chapter'] = Variable<String>(chapter);
    map['tags_snapshot'] = Variable<String>(tagsSnapshot);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  KnowledgeRevisionsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeRevisionsCompanion(
      knowledgeId: Value(knowledgeId),
      revision: Value(revision),
      title: Value(title),
      content: Value(content),
      subject: Value(subject),
      kind: Value(kind),
      chapter: Value(chapter),
      tagsSnapshot: Value(tagsSnapshot),
      createdAt: Value(createdAt),
    );
  }

  factory KnowledgeRevision.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeRevision(
      knowledgeId: serializer.fromJson<String>(json['knowledgeId']),
      revision: serializer.fromJson<int>(json['revision']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      subject: serializer.fromJson<String>(json['subject']),
      kind: serializer.fromJson<String>(json['kind']),
      chapter: serializer.fromJson<String>(json['chapter']),
      tagsSnapshot: serializer.fromJson<String>(json['tagsSnapshot']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'knowledgeId': serializer.toJson<String>(knowledgeId),
      'revision': serializer.toJson<int>(revision),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'subject': serializer.toJson<String>(subject),
      'kind': serializer.toJson<String>(kind),
      'chapter': serializer.toJson<String>(chapter),
      'tagsSnapshot': serializer.toJson<String>(tagsSnapshot),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  KnowledgeRevision copyWith({
    String? knowledgeId,
    int? revision,
    String? title,
    String? content,
    String? subject,
    String? kind,
    String? chapter,
    String? tagsSnapshot,
    DateTime? createdAt,
  }) => KnowledgeRevision(
    knowledgeId: knowledgeId ?? this.knowledgeId,
    revision: revision ?? this.revision,
    title: title ?? this.title,
    content: content ?? this.content,
    subject: subject ?? this.subject,
    kind: kind ?? this.kind,
    chapter: chapter ?? this.chapter,
    tagsSnapshot: tagsSnapshot ?? this.tagsSnapshot,
    createdAt: createdAt ?? this.createdAt,
  );
  KnowledgeRevision copyWithCompanion(KnowledgeRevisionsCompanion data) {
    return KnowledgeRevision(
      knowledgeId: data.knowledgeId.present
          ? data.knowledgeId.value
          : this.knowledgeId,
      revision: data.revision.present ? data.revision.value : this.revision,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      subject: data.subject.present ? data.subject.value : this.subject,
      kind: data.kind.present ? data.kind.value : this.kind,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      tagsSnapshot: data.tagsSnapshot.present
          ? data.tagsSnapshot.value
          : this.tagsSnapshot,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeRevision(')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('revision: $revision, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('subject: $subject, ')
          ..write('kind: $kind, ')
          ..write('chapter: $chapter, ')
          ..write('tagsSnapshot: $tagsSnapshot, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    knowledgeId,
    revision,
    title,
    content,
    subject,
    kind,
    chapter,
    tagsSnapshot,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeRevision &&
          other.knowledgeId == this.knowledgeId &&
          other.revision == this.revision &&
          other.title == this.title &&
          other.content == this.content &&
          other.subject == this.subject &&
          other.kind == this.kind &&
          other.chapter == this.chapter &&
          other.tagsSnapshot == this.tagsSnapshot &&
          other.createdAt == this.createdAt);
}

class KnowledgeRevisionsCompanion extends UpdateCompanion<KnowledgeRevision> {
  final Value<String> knowledgeId;
  final Value<int> revision;
  final Value<String> title;
  final Value<String> content;
  final Value<String> subject;
  final Value<String> kind;
  final Value<String> chapter;
  final Value<String> tagsSnapshot;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const KnowledgeRevisionsCompanion({
    this.knowledgeId = const Value.absent(),
    this.revision = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.subject = const Value.absent(),
    this.kind = const Value.absent(),
    this.chapter = const Value.absent(),
    this.tagsSnapshot = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeRevisionsCompanion.insert({
    required String knowledgeId,
    required int revision,
    required String title,
    required String content,
    required String subject,
    required String kind,
    required String chapter,
    required String tagsSnapshot,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : knowledgeId = Value(knowledgeId),
       revision = Value(revision),
       title = Value(title),
       content = Value(content),
       subject = Value(subject),
       kind = Value(kind),
       chapter = Value(chapter),
       tagsSnapshot = Value(tagsSnapshot),
       createdAt = Value(createdAt);
  static Insertable<KnowledgeRevision> custom({
    Expression<String>? knowledgeId,
    Expression<int>? revision,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? subject,
    Expression<String>? kind,
    Expression<String>? chapter,
    Expression<String>? tagsSnapshot,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (revision != null) 'revision': revision,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (subject != null) 'subject': subject,
      if (kind != null) 'kind': kind,
      if (chapter != null) 'chapter': chapter,
      if (tagsSnapshot != null) 'tags_snapshot': tagsSnapshot,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeRevisionsCompanion copyWith({
    Value<String>? knowledgeId,
    Value<int>? revision,
    Value<String>? title,
    Value<String>? content,
    Value<String>? subject,
    Value<String>? kind,
    Value<String>? chapter,
    Value<String>? tagsSnapshot,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return KnowledgeRevisionsCompanion(
      knowledgeId: knowledgeId ?? this.knowledgeId,
      revision: revision ?? this.revision,
      title: title ?? this.title,
      content: content ?? this.content,
      subject: subject ?? this.subject,
      kind: kind ?? this.kind,
      chapter: chapter ?? this.chapter,
      tagsSnapshot: tagsSnapshot ?? this.tagsSnapshot,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (knowledgeId.present) {
      map['knowledge_id'] = Variable<String>(knowledgeId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<String>(chapter.value);
    }
    if (tagsSnapshot.present) {
      map['tags_snapshot'] = Variable<String>(tagsSnapshot.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeRevisionsCompanion(')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('revision: $revision, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('subject: $subject, ')
          ..write('kind: $kind, ')
          ..write('chapter: $chapter, ')
          ..write('tagsSnapshot: $tagsSnapshot, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MistakesTable extends Mistakes with TableInfo<$MistakesTable, Mistake> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MistakesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterMeta = const VerificationMeta(
    'chapter',
  );
  @override
  late final GeneratedColumn<String> chapter = GeneratedColumn<String>(
    'chapter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _correctAnswerMeta = const VerificationMeta(
    'correctAnswer',
  );
  @override
  late final GeneratedColumn<String> correctAnswer = GeneratedColumn<String>(
    'correct_answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _originalAnswerMeta = const VerificationMeta(
    'originalAnswer',
  );
  @override
  late final GeneratedColumn<String> originalAnswer = GeneratedColumn<String>(
    'original_answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ownAnalysisMeta = const VerificationMeta(
    'ownAnalysis',
  );
  @override
  late final GeneratedColumn<String> ownAnalysis = GeneratedColumn<String>(
    'own_analysis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _aiAnalysisMeta = const VerificationMeta(
    'aiAnalysis',
  );
  @override
  late final GeneratedColumn<String> aiAnalysis = GeneratedColumn<String>(
    'ai_analysis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _errorReasonMeta = const VerificationMeta(
    'errorReason',
  );
  @override
  late final GeneratedColumn<String> errorReason = GeneratedColumn<String>(
    'error_reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('暂未确定'),
  );
  static const VerificationMeta _suggestedReasonMeta = const VerificationMeta(
    'suggestedReason',
  );
  @override
  late final GeneratedColumn<String> suggestedReason = GeneratedColumn<String>(
    'suggested_reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sourceSessionIdMeta = const VerificationMeta(
    'sourceSessionId',
  );
  @override
  late final GeneratedColumn<String> sourceSessionId = GeneratedColumn<String>(
    'source_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_messages (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    question,
    subject,
    chapter,
    correctAnswer,
    originalAnswer,
    ownAnalysis,
    aiAnalysis,
    errorReason,
    suggestedReason,
    revision,
    sourceSessionId,
    sourceMessageId,
    createdAt,
    updatedAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistakes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mistake> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('chapter')) {
      context.handle(
        _chapterMeta,
        chapter.isAcceptableOrUnknown(data['chapter']!, _chapterMeta),
      );
    }
    if (data.containsKey('correct_answer')) {
      context.handle(
        _correctAnswerMeta,
        correctAnswer.isAcceptableOrUnknown(
          data['correct_answer']!,
          _correctAnswerMeta,
        ),
      );
    }
    if (data.containsKey('original_answer')) {
      context.handle(
        _originalAnswerMeta,
        originalAnswer.isAcceptableOrUnknown(
          data['original_answer']!,
          _originalAnswerMeta,
        ),
      );
    }
    if (data.containsKey('own_analysis')) {
      context.handle(
        _ownAnalysisMeta,
        ownAnalysis.isAcceptableOrUnknown(
          data['own_analysis']!,
          _ownAnalysisMeta,
        ),
      );
    }
    if (data.containsKey('ai_analysis')) {
      context.handle(
        _aiAnalysisMeta,
        aiAnalysis.isAcceptableOrUnknown(data['ai_analysis']!, _aiAnalysisMeta),
      );
    }
    if (data.containsKey('error_reason')) {
      context.handle(
        _errorReasonMeta,
        errorReason.isAcceptableOrUnknown(
          data['error_reason']!,
          _errorReasonMeta,
        ),
      );
    }
    if (data.containsKey('suggested_reason')) {
      context.handle(
        _suggestedReasonMeta,
        suggestedReason.isAcceptableOrUnknown(
          data['suggested_reason']!,
          _suggestedReasonMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('source_session_id')) {
      context.handle(
        _sourceSessionIdMeta,
        sourceSessionId.isAcceptableOrUnknown(
          data['source_session_id']!,
          _sourceSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mistake map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mistake(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      chapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter'],
      )!,
      correctAnswer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correct_answer'],
      )!,
      originalAnswer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_answer'],
      )!,
      ownAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}own_analysis'],
      )!,
      aiAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_analysis'],
      )!,
      errorReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_reason'],
      )!,
      suggestedReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_reason'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      sourceSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_session_id'],
      ),
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $MistakesTable createAlias(String alias) {
    return $MistakesTable(attachedDatabase, alias);
  }
}

class Mistake extends DataClass implements Insertable<Mistake> {
  final String id;
  final String title;
  final String question;
  final String subject;
  final String chapter;
  final String correctAnswer;
  final String originalAnswer;
  final String ownAnalysis;
  final String aiAnalysis;
  final String errorReason;
  final String suggestedReason;
  final int revision;
  final String? sourceSessionId;
  final String? sourceMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;
  const Mistake({
    required this.id,
    required this.title,
    required this.question,
    required this.subject,
    required this.chapter,
    required this.correctAnswer,
    required this.originalAnswer,
    required this.ownAnalysis,
    required this.aiAnalysis,
    required this.errorReason,
    required this.suggestedReason,
    required this.revision,
    this.sourceSessionId,
    this.sourceMessageId,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['question'] = Variable<String>(question);
    map['subject'] = Variable<String>(subject);
    map['chapter'] = Variable<String>(chapter);
    map['correct_answer'] = Variable<String>(correctAnswer);
    map['original_answer'] = Variable<String>(originalAnswer);
    map['own_analysis'] = Variable<String>(ownAnalysis);
    map['ai_analysis'] = Variable<String>(aiAnalysis);
    map['error_reason'] = Variable<String>(errorReason);
    map['suggested_reason'] = Variable<String>(suggestedReason);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || sourceSessionId != null) {
      map['source_session_id'] = Variable<String>(sourceSessionId);
    }
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<String>(sourceMessageId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  MistakesCompanion toCompanion(bool nullToAbsent) {
    return MistakesCompanion(
      id: Value(id),
      title: Value(title),
      question: Value(question),
      subject: Value(subject),
      chapter: Value(chapter),
      correctAnswer: Value(correctAnswer),
      originalAnswer: Value(originalAnswer),
      ownAnalysis: Value(ownAnalysis),
      aiAnalysis: Value(aiAnalysis),
      errorReason: Value(errorReason),
      suggestedReason: Value(suggestedReason),
      revision: Value(revision),
      sourceSessionId: sourceSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSessionId),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
    );
  }

  factory Mistake.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mistake(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      question: serializer.fromJson<String>(json['question']),
      subject: serializer.fromJson<String>(json['subject']),
      chapter: serializer.fromJson<String>(json['chapter']),
      correctAnswer: serializer.fromJson<String>(json['correctAnswer']),
      originalAnswer: serializer.fromJson<String>(json['originalAnswer']),
      ownAnalysis: serializer.fromJson<String>(json['ownAnalysis']),
      aiAnalysis: serializer.fromJson<String>(json['aiAnalysis']),
      errorReason: serializer.fromJson<String>(json['errorReason']),
      suggestedReason: serializer.fromJson<String>(json['suggestedReason']),
      revision: serializer.fromJson<int>(json['revision']),
      sourceSessionId: serializer.fromJson<String?>(json['sourceSessionId']),
      sourceMessageId: serializer.fromJson<String?>(json['sourceMessageId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'question': serializer.toJson<String>(question),
      'subject': serializer.toJson<String>(subject),
      'chapter': serializer.toJson<String>(chapter),
      'correctAnswer': serializer.toJson<String>(correctAnswer),
      'originalAnswer': serializer.toJson<String>(originalAnswer),
      'ownAnalysis': serializer.toJson<String>(ownAnalysis),
      'aiAnalysis': serializer.toJson<String>(aiAnalysis),
      'errorReason': serializer.toJson<String>(errorReason),
      'suggestedReason': serializer.toJson<String>(suggestedReason),
      'revision': serializer.toJson<int>(revision),
      'sourceSessionId': serializer.toJson<String?>(sourceSessionId),
      'sourceMessageId': serializer.toJson<String?>(sourceMessageId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Mistake copyWith({
    String? id,
    String? title,
    String? question,
    String? subject,
    String? chapter,
    String? correctAnswer,
    String? originalAnswer,
    String? ownAnalysis,
    String? aiAnalysis,
    String? errorReason,
    String? suggestedReason,
    int? revision,
    Value<String?> sourceSessionId = const Value.absent(),
    Value<String?> sourceMessageId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
  }) => Mistake(
    id: id ?? this.id,
    title: title ?? this.title,
    question: question ?? this.question,
    subject: subject ?? this.subject,
    chapter: chapter ?? this.chapter,
    correctAnswer: correctAnswer ?? this.correctAnswer,
    originalAnswer: originalAnswer ?? this.originalAnswer,
    ownAnalysis: ownAnalysis ?? this.ownAnalysis,
    aiAnalysis: aiAnalysis ?? this.aiAnalysis,
    errorReason: errorReason ?? this.errorReason,
    suggestedReason: suggestedReason ?? this.suggestedReason,
    revision: revision ?? this.revision,
    sourceSessionId: sourceSessionId.present
        ? sourceSessionId.value
        : this.sourceSessionId,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  Mistake copyWithCompanion(MistakesCompanion data) {
    return Mistake(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      question: data.question.present ? data.question.value : this.question,
      subject: data.subject.present ? data.subject.value : this.subject,
      chapter: data.chapter.present ? data.chapter.value : this.chapter,
      correctAnswer: data.correctAnswer.present
          ? data.correctAnswer.value
          : this.correctAnswer,
      originalAnswer: data.originalAnswer.present
          ? data.originalAnswer.value
          : this.originalAnswer,
      ownAnalysis: data.ownAnalysis.present
          ? data.ownAnalysis.value
          : this.ownAnalysis,
      aiAnalysis: data.aiAnalysis.present
          ? data.aiAnalysis.value
          : this.aiAnalysis,
      errorReason: data.errorReason.present
          ? data.errorReason.value
          : this.errorReason,
      suggestedReason: data.suggestedReason.present
          ? data.suggestedReason.value
          : this.suggestedReason,
      revision: data.revision.present ? data.revision.value : this.revision,
      sourceSessionId: data.sourceSessionId.present
          ? data.sourceSessionId.value
          : this.sourceSessionId,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mistake(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('question: $question, ')
          ..write('subject: $subject, ')
          ..write('chapter: $chapter, ')
          ..write('correctAnswer: $correctAnswer, ')
          ..write('originalAnswer: $originalAnswer, ')
          ..write('ownAnalysis: $ownAnalysis, ')
          ..write('aiAnalysis: $aiAnalysis, ')
          ..write('errorReason: $errorReason, ')
          ..write('suggestedReason: $suggestedReason, ')
          ..write('revision: $revision, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    question,
    subject,
    chapter,
    correctAnswer,
    originalAnswer,
    ownAnalysis,
    aiAnalysis,
    errorReason,
    suggestedReason,
    revision,
    sourceSessionId,
    sourceMessageId,
    createdAt,
    updatedAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mistake &&
          other.id == this.id &&
          other.title == this.title &&
          other.question == this.question &&
          other.subject == this.subject &&
          other.chapter == this.chapter &&
          other.correctAnswer == this.correctAnswer &&
          other.originalAnswer == this.originalAnswer &&
          other.ownAnalysis == this.ownAnalysis &&
          other.aiAnalysis == this.aiAnalysis &&
          other.errorReason == this.errorReason &&
          other.suggestedReason == this.suggestedReason &&
          other.revision == this.revision &&
          other.sourceSessionId == this.sourceSessionId &&
          other.sourceMessageId == this.sourceMessageId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted);
}

class MistakesCompanion extends UpdateCompanion<Mistake> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> question;
  final Value<String> subject;
  final Value<String> chapter;
  final Value<String> correctAnswer;
  final Value<String> originalAnswer;
  final Value<String> ownAnalysis;
  final Value<String> aiAnalysis;
  final Value<String> errorReason;
  final Value<String> suggestedReason;
  final Value<int> revision;
  final Value<String?> sourceSessionId;
  final Value<String?> sourceMessageId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const MistakesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.question = const Value.absent(),
    this.subject = const Value.absent(),
    this.chapter = const Value.absent(),
    this.correctAnswer = const Value.absent(),
    this.originalAnswer = const Value.absent(),
    this.ownAnalysis = const Value.absent(),
    this.aiAnalysis = const Value.absent(),
    this.errorReason = const Value.absent(),
    this.suggestedReason = const Value.absent(),
    this.revision = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MistakesCompanion.insert({
    required String id,
    required String title,
    this.question = const Value.absent(),
    required String subject,
    this.chapter = const Value.absent(),
    this.correctAnswer = const Value.absent(),
    this.originalAnswer = const Value.absent(),
    this.ownAnalysis = const Value.absent(),
    this.aiAnalysis = const Value.absent(),
    this.errorReason = const Value.absent(),
    this.suggestedReason = const Value.absent(),
    this.revision = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       subject = Value(subject),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Mistake> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? question,
    Expression<String>? subject,
    Expression<String>? chapter,
    Expression<String>? correctAnswer,
    Expression<String>? originalAnswer,
    Expression<String>? ownAnalysis,
    Expression<String>? aiAnalysis,
    Expression<String>? errorReason,
    Expression<String>? suggestedReason,
    Expression<int>? revision,
    Expression<String>? sourceSessionId,
    Expression<String>? sourceMessageId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (question != null) 'question': question,
      if (subject != null) 'subject': subject,
      if (chapter != null) 'chapter': chapter,
      if (correctAnswer != null) 'correct_answer': correctAnswer,
      if (originalAnswer != null) 'original_answer': originalAnswer,
      if (ownAnalysis != null) 'own_analysis': ownAnalysis,
      if (aiAnalysis != null) 'ai_analysis': aiAnalysis,
      if (errorReason != null) 'error_reason': errorReason,
      if (suggestedReason != null) 'suggested_reason': suggestedReason,
      if (revision != null) 'revision': revision,
      if (sourceSessionId != null) 'source_session_id': sourceSessionId,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MistakesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? question,
    Value<String>? subject,
    Value<String>? chapter,
    Value<String>? correctAnswer,
    Value<String>? originalAnswer,
    Value<String>? ownAnalysis,
    Value<String>? aiAnalysis,
    Value<String>? errorReason,
    Value<String>? suggestedReason,
    Value<int>? revision,
    Value<String?>? sourceSessionId,
    Value<String?>? sourceMessageId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return MistakesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      question: question ?? this.question,
      subject: subject ?? this.subject,
      chapter: chapter ?? this.chapter,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      originalAnswer: originalAnswer ?? this.originalAnswer,
      ownAnalysis: ownAnalysis ?? this.ownAnalysis,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      errorReason: errorReason ?? this.errorReason,
      suggestedReason: suggestedReason ?? this.suggestedReason,
      revision: revision ?? this.revision,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (chapter.present) {
      map['chapter'] = Variable<String>(chapter.value);
    }
    if (correctAnswer.present) {
      map['correct_answer'] = Variable<String>(correctAnswer.value);
    }
    if (originalAnswer.present) {
      map['original_answer'] = Variable<String>(originalAnswer.value);
    }
    if (ownAnalysis.present) {
      map['own_analysis'] = Variable<String>(ownAnalysis.value);
    }
    if (aiAnalysis.present) {
      map['ai_analysis'] = Variable<String>(aiAnalysis.value);
    }
    if (errorReason.present) {
      map['error_reason'] = Variable<String>(errorReason.value);
    }
    if (suggestedReason.present) {
      map['suggested_reason'] = Variable<String>(suggestedReason.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (sourceSessionId.present) {
      map['source_session_id'] = Variable<String>(sourceSessionId.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MistakesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('question: $question, ')
          ..write('subject: $subject, ')
          ..write('chapter: $chapter, ')
          ..write('correctAnswer: $correctAnswer, ')
          ..write('originalAnswer: $originalAnswer, ')
          ..write('ownAnalysis: $ownAnalysis, ')
          ..write('aiAnalysis: $aiAnalysis, ')
          ..write('errorReason: $errorReason, ')
          ..write('suggestedReason: $suggestedReason, ')
          ..write('revision: $revision, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeTagsTable extends KnowledgeTags
    with TableInfo<$KnowledgeTagsTable, KnowledgeTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _knowledgeIdMeta = const VerificationMeta(
    'knowledgeId',
  );
  @override
  late final GeneratedColumn<String> knowledgeId = GeneratedColumn<String>(
    'knowledge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [knowledgeId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('knowledge_id')) {
      context.handle(
        _knowledgeIdMeta,
        knowledgeId.isAcceptableOrUnknown(
          data['knowledge_id']!,
          _knowledgeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_knowledgeIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {knowledgeId, tag};
  @override
  KnowledgeTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeTag(
      knowledgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $KnowledgeTagsTable createAlias(String alias) {
    return $KnowledgeTagsTable(attachedDatabase, alias);
  }
}

class KnowledgeTag extends DataClass implements Insertable<KnowledgeTag> {
  final String knowledgeId;
  final String tag;
  const KnowledgeTag({required this.knowledgeId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['knowledge_id'] = Variable<String>(knowledgeId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  KnowledgeTagsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeTagsCompanion(
      knowledgeId: Value(knowledgeId),
      tag: Value(tag),
    );
  }

  factory KnowledgeTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeTag(
      knowledgeId: serializer.fromJson<String>(json['knowledgeId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'knowledgeId': serializer.toJson<String>(knowledgeId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  KnowledgeTag copyWith({String? knowledgeId, String? tag}) => KnowledgeTag(
    knowledgeId: knowledgeId ?? this.knowledgeId,
    tag: tag ?? this.tag,
  );
  KnowledgeTag copyWithCompanion(KnowledgeTagsCompanion data) {
    return KnowledgeTag(
      knowledgeId: data.knowledgeId.present
          ? data.knowledgeId.value
          : this.knowledgeId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeTag(')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(knowledgeId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeTag &&
          other.knowledgeId == this.knowledgeId &&
          other.tag == this.tag);
}

class KnowledgeTagsCompanion extends UpdateCompanion<KnowledgeTag> {
  final Value<String> knowledgeId;
  final Value<String> tag;
  final Value<int> rowid;
  const KnowledgeTagsCompanion({
    this.knowledgeId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeTagsCompanion.insert({
    required String knowledgeId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : knowledgeId = Value(knowledgeId),
       tag = Value(tag);
  static Insertable<KnowledgeTag> custom({
    Expression<String>? knowledgeId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeTagsCompanion copyWith({
    Value<String>? knowledgeId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return KnowledgeTagsCompanion(
      knowledgeId: knowledgeId ?? this.knowledgeId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (knowledgeId.present) {
      map['knowledge_id'] = Variable<String>(knowledgeId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeTagsCompanion(')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MistakeTagsTable extends MistakeTags
    with TableInfo<$MistakeTagsTable, MistakeTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MistakeTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mistakeIdMeta = const VerificationMeta(
    'mistakeId',
  );
  @override
  late final GeneratedColumn<String> mistakeId = GeneratedColumn<String>(
    'mistake_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mistakes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [mistakeId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistake_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<MistakeTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mistake_id')) {
      context.handle(
        _mistakeIdMeta,
        mistakeId.isAcceptableOrUnknown(data['mistake_id']!, _mistakeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mistakeIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mistakeId, tag};
  @override
  MistakeTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MistakeTag(
      mistakeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mistake_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $MistakeTagsTable createAlias(String alias) {
    return $MistakeTagsTable(attachedDatabase, alias);
  }
}

class MistakeTag extends DataClass implements Insertable<MistakeTag> {
  final String mistakeId;
  final String tag;
  const MistakeTag({required this.mistakeId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mistake_id'] = Variable<String>(mistakeId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  MistakeTagsCompanion toCompanion(bool nullToAbsent) {
    return MistakeTagsCompanion(mistakeId: Value(mistakeId), tag: Value(tag));
  }

  factory MistakeTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MistakeTag(
      mistakeId: serializer.fromJson<String>(json['mistakeId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mistakeId': serializer.toJson<String>(mistakeId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  MistakeTag copyWith({String? mistakeId, String? tag}) =>
      MistakeTag(mistakeId: mistakeId ?? this.mistakeId, tag: tag ?? this.tag);
  MistakeTag copyWithCompanion(MistakeTagsCompanion data) {
    return MistakeTag(
      mistakeId: data.mistakeId.present ? data.mistakeId.value : this.mistakeId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MistakeTag(')
          ..write('mistakeId: $mistakeId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mistakeId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MistakeTag &&
          other.mistakeId == this.mistakeId &&
          other.tag == this.tag);
}

class MistakeTagsCompanion extends UpdateCompanion<MistakeTag> {
  final Value<String> mistakeId;
  final Value<String> tag;
  final Value<int> rowid;
  const MistakeTagsCompanion({
    this.mistakeId = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MistakeTagsCompanion.insert({
    required String mistakeId,
    required String tag,
    this.rowid = const Value.absent(),
  }) : mistakeId = Value(mistakeId),
       tag = Value(tag);
  static Insertable<MistakeTag> custom({
    Expression<String>? mistakeId,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mistakeId != null) 'mistake_id': mistakeId,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MistakeTagsCompanion copyWith({
    Value<String>? mistakeId,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return MistakeTagsCompanion(
      mistakeId: mistakeId ?? this.mistakeId,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mistakeId.present) {
      map['mistake_id'] = Variable<String>(mistakeId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MistakeTagsCompanion(')
          ..write('mistakeId: $mistakeId, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeRelationsTable extends KnowledgeRelations
    with TableInfo<$KnowledgeRelationsTable, KnowledgeRelation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeRelationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [sourceId, targetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_relations';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeRelation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, targetId};
  @override
  KnowledgeRelation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeRelation(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
    );
  }

  @override
  $KnowledgeRelationsTable createAlias(String alias) {
    return $KnowledgeRelationsTable(attachedDatabase, alias);
  }
}

class KnowledgeRelation extends DataClass
    implements Insertable<KnowledgeRelation> {
  final String sourceId;
  final String targetId;
  const KnowledgeRelation({required this.sourceId, required this.targetId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['target_id'] = Variable<String>(targetId);
    return map;
  }

  KnowledgeRelationsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeRelationsCompanion(
      sourceId: Value(sourceId),
      targetId: Value(targetId),
    );
  }

  factory KnowledgeRelation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeRelation(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      targetId: serializer.fromJson<String>(json['targetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'targetId': serializer.toJson<String>(targetId),
    };
  }

  KnowledgeRelation copyWith({String? sourceId, String? targetId}) =>
      KnowledgeRelation(
        sourceId: sourceId ?? this.sourceId,
        targetId: targetId ?? this.targetId,
      );
  KnowledgeRelation copyWithCompanion(KnowledgeRelationsCompanion data) {
    return KnowledgeRelation(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeRelation(')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, targetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeRelation &&
          other.sourceId == this.sourceId &&
          other.targetId == this.targetId);
}

class KnowledgeRelationsCompanion extends UpdateCompanion<KnowledgeRelation> {
  final Value<String> sourceId;
  final Value<String> targetId;
  final Value<int> rowid;
  const KnowledgeRelationsCompanion({
    this.sourceId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeRelationsCompanion.insert({
    required String sourceId,
    required String targetId,
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       targetId = Value(targetId);
  static Insertable<KnowledgeRelation> custom({
    Expression<String>? sourceId,
    Expression<String>? targetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (targetId != null) 'target_id': targetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeRelationsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? targetId,
    Value<int>? rowid,
  }) {
    return KnowledgeRelationsCompanion(
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeRelationsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MistakeKnowledgeLinksTable extends MistakeKnowledgeLinks
    with TableInfo<$MistakeKnowledgeLinksTable, MistakeKnowledgeLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MistakeKnowledgeLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mistakeIdMeta = const VerificationMeta(
    'mistakeId',
  );
  @override
  late final GeneratedColumn<String> mistakeId = GeneratedColumn<String>(
    'mistake_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mistakes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _knowledgeIdMeta = const VerificationMeta(
    'knowledgeId',
  );
  @override
  late final GeneratedColumn<String> knowledgeId = GeneratedColumn<String>(
    'knowledge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [mistakeId, knowledgeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mistake_knowledge_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<MistakeKnowledgeLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('mistake_id')) {
      context.handle(
        _mistakeIdMeta,
        mistakeId.isAcceptableOrUnknown(data['mistake_id']!, _mistakeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mistakeIdMeta);
    }
    if (data.containsKey('knowledge_id')) {
      context.handle(
        _knowledgeIdMeta,
        knowledgeId.isAcceptableOrUnknown(
          data['knowledge_id']!,
          _knowledgeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_knowledgeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mistakeId, knowledgeId};
  @override
  MistakeKnowledgeLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MistakeKnowledgeLink(
      mistakeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mistake_id'],
      )!,
      knowledgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_id'],
      )!,
    );
  }

  @override
  $MistakeKnowledgeLinksTable createAlias(String alias) {
    return $MistakeKnowledgeLinksTable(attachedDatabase, alias);
  }
}

class MistakeKnowledgeLink extends DataClass
    implements Insertable<MistakeKnowledgeLink> {
  final String mistakeId;
  final String knowledgeId;
  const MistakeKnowledgeLink({
    required this.mistakeId,
    required this.knowledgeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['mistake_id'] = Variable<String>(mistakeId);
    map['knowledge_id'] = Variable<String>(knowledgeId);
    return map;
  }

  MistakeKnowledgeLinksCompanion toCompanion(bool nullToAbsent) {
    return MistakeKnowledgeLinksCompanion(
      mistakeId: Value(mistakeId),
      knowledgeId: Value(knowledgeId),
    );
  }

  factory MistakeKnowledgeLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MistakeKnowledgeLink(
      mistakeId: serializer.fromJson<String>(json['mistakeId']),
      knowledgeId: serializer.fromJson<String>(json['knowledgeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mistakeId': serializer.toJson<String>(mistakeId),
      'knowledgeId': serializer.toJson<String>(knowledgeId),
    };
  }

  MistakeKnowledgeLink copyWith({String? mistakeId, String? knowledgeId}) =>
      MistakeKnowledgeLink(
        mistakeId: mistakeId ?? this.mistakeId,
        knowledgeId: knowledgeId ?? this.knowledgeId,
      );
  MistakeKnowledgeLink copyWithCompanion(MistakeKnowledgeLinksCompanion data) {
    return MistakeKnowledgeLink(
      mistakeId: data.mistakeId.present ? data.mistakeId.value : this.mistakeId,
      knowledgeId: data.knowledgeId.present
          ? data.knowledgeId.value
          : this.knowledgeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MistakeKnowledgeLink(')
          ..write('mistakeId: $mistakeId, ')
          ..write('knowledgeId: $knowledgeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mistakeId, knowledgeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MistakeKnowledgeLink &&
          other.mistakeId == this.mistakeId &&
          other.knowledgeId == this.knowledgeId);
}

class MistakeKnowledgeLinksCompanion
    extends UpdateCompanion<MistakeKnowledgeLink> {
  final Value<String> mistakeId;
  final Value<String> knowledgeId;
  final Value<int> rowid;
  const MistakeKnowledgeLinksCompanion({
    this.mistakeId = const Value.absent(),
    this.knowledgeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MistakeKnowledgeLinksCompanion.insert({
    required String mistakeId,
    required String knowledgeId,
    this.rowid = const Value.absent(),
  }) : mistakeId = Value(mistakeId),
       knowledgeId = Value(knowledgeId);
  static Insertable<MistakeKnowledgeLink> custom({
    Expression<String>? mistakeId,
    Expression<String>? knowledgeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mistakeId != null) 'mistake_id': mistakeId,
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MistakeKnowledgeLinksCompanion copyWith({
    Value<String>? mistakeId,
    Value<String>? knowledgeId,
    Value<int>? rowid,
  }) {
    return MistakeKnowledgeLinksCompanion(
      mistakeId: mistakeId ?? this.mistakeId,
      knowledgeId: knowledgeId ?? this.knowledgeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mistakeId.present) {
      map['mistake_id'] = Variable<String>(mistakeId.value);
    }
    if (knowledgeId.present) {
      map['knowledge_id'] = Variable<String>(knowledgeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MistakeKnowledgeLinksCompanion(')
          ..write('mistakeId: $mistakeId, ')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyAttachmentsTable extends StudyAttachments
    with TableInfo<$StudyAttachmentsTable, StudyAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _knowledgeIdMeta = const VerificationMeta(
    'knowledgeId',
  );
  @override
  late final GeneratedColumn<String> knowledgeId = GeneratedColumn<String>(
    'knowledge_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _mistakeIdMeta = const VerificationMeta(
    'mistakeId',
  );
  @override
  late final GeneratedColumn<String> mistakeId = GeneratedColumn<String>(
    'mistake_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mistakes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES study_attachments (id)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('original'),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    knowledgeId,
    mistakeId,
    relativePath,
    mime,
    byteLength,
    parentId,
    role,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('knowledge_id')) {
      context.handle(
        _knowledgeIdMeta,
        knowledgeId.isAcceptableOrUnknown(
          data['knowledge_id']!,
          _knowledgeIdMeta,
        ),
      );
    }
    if (data.containsKey('mistake_id')) {
      context.handle(
        _mistakeIdMeta,
        mistakeId.isAcceptableOrUnknown(data['mistake_id']!, _mistakeIdMeta),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudyAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyAttachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      knowledgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_id'],
      ),
      mistakeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mistake_id'],
      ),
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $StudyAttachmentsTable createAlias(String alias) {
    return $StudyAttachmentsTable(attachedDatabase, alias);
  }
}

class StudyAttachment extends DataClass implements Insertable<StudyAttachment> {
  final String id;
  final String? knowledgeId;
  final String? mistakeId;
  final String relativePath;
  final String mime;
  final int byteLength;
  final String? parentId;
  final String role;
  final bool deleted;
  const StudyAttachment({
    required this.id,
    this.knowledgeId,
    this.mistakeId,
    required this.relativePath,
    required this.mime,
    required this.byteLength,
    this.parentId,
    required this.role,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || knowledgeId != null) {
      map['knowledge_id'] = Variable<String>(knowledgeId);
    }
    if (!nullToAbsent || mistakeId != null) {
      map['mistake_id'] = Variable<String>(mistakeId);
    }
    map['relative_path'] = Variable<String>(relativePath);
    map['mime'] = Variable<String>(mime);
    map['byte_length'] = Variable<int>(byteLength);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['role'] = Variable<String>(role);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  StudyAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return StudyAttachmentsCompanion(
      id: Value(id),
      knowledgeId: knowledgeId == null && nullToAbsent
          ? const Value.absent()
          : Value(knowledgeId),
      mistakeId: mistakeId == null && nullToAbsent
          ? const Value.absent()
          : Value(mistakeId),
      relativePath: Value(relativePath),
      mime: Value(mime),
      byteLength: Value(byteLength),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      role: Value(role),
      deleted: Value(deleted),
    );
  }

  factory StudyAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyAttachment(
      id: serializer.fromJson<String>(json['id']),
      knowledgeId: serializer.fromJson<String?>(json['knowledgeId']),
      mistakeId: serializer.fromJson<String?>(json['mistakeId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mime: serializer.fromJson<String>(json['mime']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      role: serializer.fromJson<String>(json['role']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'knowledgeId': serializer.toJson<String?>(knowledgeId),
      'mistakeId': serializer.toJson<String?>(mistakeId),
      'relativePath': serializer.toJson<String>(relativePath),
      'mime': serializer.toJson<String>(mime),
      'byteLength': serializer.toJson<int>(byteLength),
      'parentId': serializer.toJson<String?>(parentId),
      'role': serializer.toJson<String>(role),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  StudyAttachment copyWith({
    String? id,
    Value<String?> knowledgeId = const Value.absent(),
    Value<String?> mistakeId = const Value.absent(),
    String? relativePath,
    String? mime,
    int? byteLength,
    Value<String?> parentId = const Value.absent(),
    String? role,
    bool? deleted,
  }) => StudyAttachment(
    id: id ?? this.id,
    knowledgeId: knowledgeId.present ? knowledgeId.value : this.knowledgeId,
    mistakeId: mistakeId.present ? mistakeId.value : this.mistakeId,
    relativePath: relativePath ?? this.relativePath,
    mime: mime ?? this.mime,
    byteLength: byteLength ?? this.byteLength,
    parentId: parentId.present ? parentId.value : this.parentId,
    role: role ?? this.role,
    deleted: deleted ?? this.deleted,
  );
  StudyAttachment copyWithCompanion(StudyAttachmentsCompanion data) {
    return StudyAttachment(
      id: data.id.present ? data.id.value : this.id,
      knowledgeId: data.knowledgeId.present
          ? data.knowledgeId.value
          : this.knowledgeId,
      mistakeId: data.mistakeId.present ? data.mistakeId.value : this.mistakeId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mime: data.mime.present ? data.mime.value : this.mime,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      role: data.role.present ? data.role.value : this.role,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyAttachment(')
          ..write('id: $id, ')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('mistakeId: $mistakeId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength, ')
          ..write('parentId: $parentId, ')
          ..write('role: $role, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    knowledgeId,
    mistakeId,
    relativePath,
    mime,
    byteLength,
    parentId,
    role,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyAttachment &&
          other.id == this.id &&
          other.knowledgeId == this.knowledgeId &&
          other.mistakeId == this.mistakeId &&
          other.relativePath == this.relativePath &&
          other.mime == this.mime &&
          other.byteLength == this.byteLength &&
          other.parentId == this.parentId &&
          other.role == this.role &&
          other.deleted == this.deleted);
}

class StudyAttachmentsCompanion extends UpdateCompanion<StudyAttachment> {
  final Value<String> id;
  final Value<String?> knowledgeId;
  final Value<String?> mistakeId;
  final Value<String> relativePath;
  final Value<String> mime;
  final Value<int> byteLength;
  final Value<String?> parentId;
  final Value<String> role;
  final Value<bool> deleted;
  final Value<int> rowid;
  const StudyAttachmentsCompanion({
    this.id = const Value.absent(),
    this.knowledgeId = const Value.absent(),
    this.mistakeId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.parentId = const Value.absent(),
    this.role = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyAttachmentsCompanion.insert({
    required String id,
    this.knowledgeId = const Value.absent(),
    this.mistakeId = const Value.absent(),
    required String relativePath,
    required String mime,
    required int byteLength,
    this.parentId = const Value.absent(),
    this.role = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       relativePath = Value(relativePath),
       mime = Value(mime),
       byteLength = Value(byteLength);
  static Insertable<StudyAttachment> custom({
    Expression<String>? id,
    Expression<String>? knowledgeId,
    Expression<String>? mistakeId,
    Expression<String>? relativePath,
    Expression<String>? mime,
    Expression<int>? byteLength,
    Expression<String>? parentId,
    Expression<String>? role,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (mistakeId != null) 'mistake_id': mistakeId,
      if (relativePath != null) 'relative_path': relativePath,
      if (mime != null) 'mime': mime,
      if (byteLength != null) 'byte_length': byteLength,
      if (parentId != null) 'parent_id': parentId,
      if (role != null) 'role': role,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? knowledgeId,
    Value<String?>? mistakeId,
    Value<String>? relativePath,
    Value<String>? mime,
    Value<int>? byteLength,
    Value<String?>? parentId,
    Value<String>? role,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return StudyAttachmentsCompanion(
      id: id ?? this.id,
      knowledgeId: knowledgeId ?? this.knowledgeId,
      mistakeId: mistakeId ?? this.mistakeId,
      relativePath: relativePath ?? this.relativePath,
      mime: mime ?? this.mime,
      byteLength: byteLength ?? this.byteLength,
      parentId: parentId ?? this.parentId,
      role: role ?? this.role,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (knowledgeId.present) {
      map['knowledge_id'] = Variable<String>(knowledgeId.value);
    }
    if (mistakeId.present) {
      map['mistake_id'] = Variable<String>(mistakeId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('mistakeId: $mistakeId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength, ')
          ..write('parentId: $parentId, ')
          ..write('role: $role, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiToolOperationsTable extends AiToolOperations
    with TableInfo<$AiToolOperationsTable, AiToolOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiToolOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _argumentsMeta = const VerificationMeta(
    'arguments',
  );
  @override
  late final GeneratedColumn<String> arguments = GeneratedColumn<String>(
    'arguments',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    sessionId,
    name,
    arguments,
    status,
    result,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_tool_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiToolOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('arguments')) {
      context.handle(
        _argumentsMeta,
        arguments.isAcceptableOrUnknown(data['arguments']!, _argumentsMeta),
      );
    } else if (isInserting) {
      context.missing(_argumentsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiToolOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiToolOperation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      arguments: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arguments'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AiToolOperationsTable createAlias(String alias) {
    return $AiToolOperationsTable(attachedDatabase, alias);
  }
}

class AiToolOperation extends DataClass implements Insertable<AiToolOperation> {
  final String id;
  final String runId;
  final String sessionId;
  final String name;
  final String arguments;
  final String status;
  final String? result;
  final DateTime createdAt;
  const AiToolOperation({
    required this.id,
    required this.runId,
    required this.sessionId,
    required this.name,
    required this.arguments,
    required this.status,
    this.result,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['session_id'] = Variable<String>(sessionId);
    map['name'] = Variable<String>(name);
    map['arguments'] = Variable<String>(arguments);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(result);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AiToolOperationsCompanion toCompanion(bool nullToAbsent) {
    return AiToolOperationsCompanion(
      id: Value(id),
      runId: Value(runId),
      sessionId: Value(sessionId),
      name: Value(name),
      arguments: Value(arguments),
      status: Value(status),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      createdAt: Value(createdAt),
    );
  }

  factory AiToolOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiToolOperation(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      name: serializer.fromJson<String>(json['name']),
      arguments: serializer.fromJson<String>(json['arguments']),
      status: serializer.fromJson<String>(json['status']),
      result: serializer.fromJson<String?>(json['result']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'sessionId': serializer.toJson<String>(sessionId),
      'name': serializer.toJson<String>(name),
      'arguments': serializer.toJson<String>(arguments),
      'status': serializer.toJson<String>(status),
      'result': serializer.toJson<String?>(result),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AiToolOperation copyWith({
    String? id,
    String? runId,
    String? sessionId,
    String? name,
    String? arguments,
    String? status,
    Value<String?> result = const Value.absent(),
    DateTime? createdAt,
  }) => AiToolOperation(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    sessionId: sessionId ?? this.sessionId,
    name: name ?? this.name,
    arguments: arguments ?? this.arguments,
    status: status ?? this.status,
    result: result.present ? result.value : this.result,
    createdAt: createdAt ?? this.createdAt,
  );
  AiToolOperation copyWithCompanion(AiToolOperationsCompanion data) {
    return AiToolOperation(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      name: data.name.present ? data.name.value : this.name,
      arguments: data.arguments.present ? data.arguments.value : this.arguments,
      status: data.status.present ? data.status.value : this.status,
      result: data.result.present ? data.result.value : this.result,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiToolOperation(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('arguments: $arguments, ')
          ..write('status: $status, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    sessionId,
    name,
    arguments,
    status,
    result,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiToolOperation &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.sessionId == this.sessionId &&
          other.name == this.name &&
          other.arguments == this.arguments &&
          other.status == this.status &&
          other.result == this.result &&
          other.createdAt == this.createdAt);
}

class AiToolOperationsCompanion extends UpdateCompanion<AiToolOperation> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> sessionId;
  final Value<String> name;
  final Value<String> arguments;
  final Value<String> status;
  final Value<String?> result;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AiToolOperationsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.name = const Value.absent(),
    this.arguments = const Value.absent(),
    this.status = const Value.absent(),
    this.result = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiToolOperationsCompanion.insert({
    required String id,
    required String runId,
    required String sessionId,
    required String name,
    required String arguments,
    required String status,
    this.result = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       sessionId = Value(sessionId),
       name = Value(name),
       arguments = Value(arguments),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<AiToolOperation> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? sessionId,
    Expression<String>? name,
    Expression<String>? arguments,
    Expression<String>? status,
    Expression<String>? result,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (sessionId != null) 'session_id': sessionId,
      if (name != null) 'name': name,
      if (arguments != null) 'arguments': arguments,
      if (status != null) 'status': status,
      if (result != null) 'result': result,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiToolOperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? sessionId,
    Value<String>? name,
    Value<String>? arguments,
    Value<String>? status,
    Value<String?>? result,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AiToolOperationsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      sessionId: sessionId ?? this.sessionId,
      name: name ?? this.name,
      arguments: arguments ?? this.arguments,
      status: status ?? this.status,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (arguments.present) {
      map['arguments'] = Variable<String>(arguments.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiToolOperationsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sessionId: $sessionId, ')
          ..write('name: $name, ')
          ..write('arguments: $arguments, ')
          ..write('status: $status, ')
          ..write('result: $result, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyChatLinksTable extends StudyChatLinks
    with TableInfo<$StudyChatLinksTable, StudyChatLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyChatLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _knowledgeIdMeta = const VerificationMeta(
    'knowledgeId',
  );
  @override
  late final GeneratedColumn<String> knowledgeId = GeneratedColumn<String>(
    'knowledge_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _mistakeIdMeta = const VerificationMeta(
    'mistakeId',
  );
  @override
  late final GeneratedColumn<String> mistakeId = GeneratedColumn<String>(
    'mistake_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mistakes (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, knowledgeId, mistakeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_chat_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyChatLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('knowledge_id')) {
      context.handle(
        _knowledgeIdMeta,
        knowledgeId.isAcceptableOrUnknown(
          data['knowledge_id']!,
          _knowledgeIdMeta,
        ),
      );
    }
    if (data.containsKey('mistake_id')) {
      context.handle(
        _mistakeIdMeta,
        mistakeId.isAcceptableOrUnknown(data['mistake_id']!, _mistakeIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sessionId, knowledgeId},
    {sessionId, mistakeId},
  ];
  @override
  StudyChatLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyChatLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      knowledgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_id'],
      ),
      mistakeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mistake_id'],
      ),
    );
  }

  @override
  $StudyChatLinksTable createAlias(String alias) {
    return $StudyChatLinksTable(attachedDatabase, alias);
  }
}

class StudyChatLink extends DataClass implements Insertable<StudyChatLink> {
  final String id;
  final String sessionId;
  final String? knowledgeId;
  final String? mistakeId;
  const StudyChatLink({
    required this.id,
    required this.sessionId,
    this.knowledgeId,
    this.mistakeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || knowledgeId != null) {
      map['knowledge_id'] = Variable<String>(knowledgeId);
    }
    if (!nullToAbsent || mistakeId != null) {
      map['mistake_id'] = Variable<String>(mistakeId);
    }
    return map;
  }

  StudyChatLinksCompanion toCompanion(bool nullToAbsent) {
    return StudyChatLinksCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      knowledgeId: knowledgeId == null && nullToAbsent
          ? const Value.absent()
          : Value(knowledgeId),
      mistakeId: mistakeId == null && nullToAbsent
          ? const Value.absent()
          : Value(mistakeId),
    );
  }

  factory StudyChatLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyChatLink(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      knowledgeId: serializer.fromJson<String?>(json['knowledgeId']),
      mistakeId: serializer.fromJson<String?>(json['mistakeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'knowledgeId': serializer.toJson<String?>(knowledgeId),
      'mistakeId': serializer.toJson<String?>(mistakeId),
    };
  }

  StudyChatLink copyWith({
    String? id,
    String? sessionId,
    Value<String?> knowledgeId = const Value.absent(),
    Value<String?> mistakeId = const Value.absent(),
  }) => StudyChatLink(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    knowledgeId: knowledgeId.present ? knowledgeId.value : this.knowledgeId,
    mistakeId: mistakeId.present ? mistakeId.value : this.mistakeId,
  );
  StudyChatLink copyWithCompanion(StudyChatLinksCompanion data) {
    return StudyChatLink(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      knowledgeId: data.knowledgeId.present
          ? data.knowledgeId.value
          : this.knowledgeId,
      mistakeId: data.mistakeId.present ? data.mistakeId.value : this.mistakeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyChatLink(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('mistakeId: $mistakeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, knowledgeId, mistakeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyChatLink &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.knowledgeId == this.knowledgeId &&
          other.mistakeId == this.mistakeId);
}

class StudyChatLinksCompanion extends UpdateCompanion<StudyChatLink> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> knowledgeId;
  final Value<String?> mistakeId;
  final Value<int> rowid;
  const StudyChatLinksCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.knowledgeId = const Value.absent(),
    this.mistakeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyChatLinksCompanion.insert({
    required String id,
    required String sessionId,
    this.knowledgeId = const Value.absent(),
    this.mistakeId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId);
  static Insertable<StudyChatLink> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? knowledgeId,
    Expression<String>? mistakeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (mistakeId != null) 'mistake_id': mistakeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyChatLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String?>? knowledgeId,
    Value<String?>? mistakeId,
    Value<int>? rowid,
  }) {
    return StudyChatLinksCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      knowledgeId: knowledgeId ?? this.knowledgeId,
      mistakeId: mistakeId ?? this.mistakeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (knowledgeId.present) {
      map['knowledge_id'] = Variable<String>(knowledgeId.value);
    }
    if (mistakeId.present) {
      map['mistake_id'] = Variable<String>(mistakeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyChatLinksCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('mistakeId: $mistakeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearningTopicsTable extends LearningTopics
    with TableInfo<$LearningTopicsTable, LearningTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearningTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, subject];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learning_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearningTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name, subject},
  ];
  @override
  LearningTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearningTopic(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
    );
  }

  @override
  $LearningTopicsTable createAlias(String alias) {
    return $LearningTopicsTable(attachedDatabase, alias);
  }
}

class LearningTopic extends DataClass implements Insertable<LearningTopic> {
  final String id;
  final String name;
  final String subject;
  const LearningTopic({
    required this.id,
    required this.name,
    required this.subject,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['subject'] = Variable<String>(subject);
    return map;
  }

  LearningTopicsCompanion toCompanion(bool nullToAbsent) {
    return LearningTopicsCompanion(
      id: Value(id),
      name: Value(name),
      subject: Value(subject),
    );
  }

  factory LearningTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearningTopic(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      subject: serializer.fromJson<String>(json['subject']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'subject': serializer.toJson<String>(subject),
    };
  }

  LearningTopic copyWith({String? id, String? name, String? subject}) =>
      LearningTopic(
        id: id ?? this.id,
        name: name ?? this.name,
        subject: subject ?? this.subject,
      );
  LearningTopic copyWithCompanion(LearningTopicsCompanion data) {
    return LearningTopic(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      subject: data.subject.present ? data.subject.value : this.subject,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearningTopic(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('subject: $subject')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, subject);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningTopic &&
          other.id == this.id &&
          other.name == this.name &&
          other.subject == this.subject);
}

class LearningTopicsCompanion extends UpdateCompanion<LearningTopic> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> subject;
  final Value<int> rowid;
  const LearningTopicsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.subject = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearningTopicsCompanion.insert({
    required String id,
    required String name,
    required String subject,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       subject = Value(subject);
  static Insertable<LearningTopic> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? subject,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (subject != null) 'subject': subject,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearningTopicsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? subject,
    Value<int>? rowid,
  }) {
    return LearningTopicsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearningTopicsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('subject: $subject, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeQuestionsTable extends PracticeQuestions
    with TableInfo<$PracticeQuestionsTable, PracticeQuestion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeQuestionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stemMeta = const VerificationMeta('stem');
  @override
  late final GeneratedColumn<String> stem = GeneratedColumn<String>(
    'stem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectMeta = const VerificationMeta(
    'subject',
  );
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
    'subject',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _hintMeta = const VerificationMeta('hint');
  @override
  late final GeneratedColumn<String> hint = GeneratedColumn<String>(
    'hint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verificationMeta = const VerificationMeta(
    'verification',
  );
  @override
  late final GeneratedColumn<String> verification = GeneratedColumn<String>(
    'verification',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unverified'),
  );
  static const VerificationMeta _absoluteToleranceMeta = const VerificationMeta(
    'absoluteTolerance',
  );
  @override
  late final GeneratedColumn<double> absoluteTolerance =
      GeneratedColumn<double>(
        'absolute_tolerance',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.000001),
      );
  static const VerificationMeta _relativeToleranceMeta = const VerificationMeta(
    'relativeTolerance',
  );
  @override
  late final GeneratedColumn<double> relativeTolerance =
      GeneratedColumn<double>(
        'relative_tolerance',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _caseSensitiveMeta = const VerificationMeta(
    'caseSensitive',
  );
  @override
  late final GeneratedColumn<bool> caseSensitive = GeneratedColumn<bool>(
    'case_sensitive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("case_sensitive" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _timeLimitSecondsMeta = const VerificationMeta(
    'timeLimitSeconds',
  );
  @override
  late final GeneratedColumn<int> timeLimitSeconds = GeneratedColumn<int>(
    'time_limit_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceSessionIdMeta = const VerificationMeta(
    'sourceSessionId',
  );
  @override
  late final GeneratedColumn<String> sourceSessionId = GeneratedColumn<String>(
    'source_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_sessions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sourceMessageIdMeta = const VerificationMeta(
    'sourceMessageId',
  );
  @override
  late final GeneratedColumn<String> sourceMessageId = GeneratedColumn<String>(
    'source_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_messages (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sourceOperationMeta = const VerificationMeta(
    'sourceOperation',
  );
  @override
  late final GeneratedColumn<String> sourceOperation = GeneratedColumn<String>(
    'source_operation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _mistakeIdMeta = const VerificationMeta(
    'mistakeId',
  );
  @override
  late final GeneratedColumn<String> mistakeId = GeneratedColumn<String>(
    'mistake_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mistakes (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _parentQuestionIdMeta = const VerificationMeta(
    'parentQuestionId',
  );
  @override
  late final GeneratedColumn<String> parentQuestionId = GeneratedColumn<String>(
    'parent_question_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    stem,
    subject,
    explanation,
    hint,
    origin,
    verification,
    absoluteTolerance,
    relativeTolerance,
    caseSensitive,
    timeLimitSeconds,
    sourceSessionId,
    sourceMessageId,
    sourceOperation,
    mistakeId,
    parentQuestionId,
    createdAt,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_questions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeQuestion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('stem')) {
      context.handle(
        _stemMeta,
        stem.isAcceptableOrUnknown(data['stem']!, _stemMeta),
      );
    } else if (isInserting) {
      context.missing(_stemMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(
        _subjectMeta,
        subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    }
    if (data.containsKey('hint')) {
      context.handle(
        _hintMeta,
        hint.isAcceptableOrUnknown(data['hint']!, _hintMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('verification')) {
      context.handle(
        _verificationMeta,
        verification.isAcceptableOrUnknown(
          data['verification']!,
          _verificationMeta,
        ),
      );
    }
    if (data.containsKey('absolute_tolerance')) {
      context.handle(
        _absoluteToleranceMeta,
        absoluteTolerance.isAcceptableOrUnknown(
          data['absolute_tolerance']!,
          _absoluteToleranceMeta,
        ),
      );
    }
    if (data.containsKey('relative_tolerance')) {
      context.handle(
        _relativeToleranceMeta,
        relativeTolerance.isAcceptableOrUnknown(
          data['relative_tolerance']!,
          _relativeToleranceMeta,
        ),
      );
    }
    if (data.containsKey('case_sensitive')) {
      context.handle(
        _caseSensitiveMeta,
        caseSensitive.isAcceptableOrUnknown(
          data['case_sensitive']!,
          _caseSensitiveMeta,
        ),
      );
    }
    if (data.containsKey('time_limit_seconds')) {
      context.handle(
        _timeLimitSecondsMeta,
        timeLimitSeconds.isAcceptableOrUnknown(
          data['time_limit_seconds']!,
          _timeLimitSecondsMeta,
        ),
      );
    }
    if (data.containsKey('source_session_id')) {
      context.handle(
        _sourceSessionIdMeta,
        sourceSessionId.isAcceptableOrUnknown(
          data['source_session_id']!,
          _sourceSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('source_message_id')) {
      context.handle(
        _sourceMessageIdMeta,
        sourceMessageId.isAcceptableOrUnknown(
          data['source_message_id']!,
          _sourceMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('source_operation')) {
      context.handle(
        _sourceOperationMeta,
        sourceOperation.isAcceptableOrUnknown(
          data['source_operation']!,
          _sourceOperationMeta,
        ),
      );
    }
    if (data.containsKey('mistake_id')) {
      context.handle(
        _mistakeIdMeta,
        mistakeId.isAcceptableOrUnknown(data['mistake_id']!, _mistakeIdMeta),
      );
    }
    if (data.containsKey('parent_question_id')) {
      context.handle(
        _parentQuestionIdMeta,
        parentQuestionId.isAcceptableOrUnknown(
          data['parent_question_id']!,
          _parentQuestionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeQuestion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeQuestion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      stem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stem'],
      )!,
      subject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      hint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hint'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      verification: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification'],
      )!,
      absoluteTolerance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}absolute_tolerance'],
      )!,
      relativeTolerance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}relative_tolerance'],
      )!,
      caseSensitive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}case_sensitive'],
      )!,
      timeLimitSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_limit_seconds'],
      ),
      sourceSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_session_id'],
      ),
      sourceMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_message_id'],
      ),
      sourceOperation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_operation'],
      ),
      mistakeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mistake_id'],
      ),
      parentQuestionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_question_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $PracticeQuestionsTable createAlias(String alias) {
    return $PracticeQuestionsTable(attachedDatabase, alias);
  }
}

class PracticeQuestion extends DataClass
    implements Insertable<PracticeQuestion> {
  final String id;
  final String kind;
  final String stem;
  final String subject;
  final String explanation;
  final String hint;
  final String origin;
  final String verification;
  final double absoluteTolerance;
  final double relativeTolerance;
  final bool caseSensitive;
  final int? timeLimitSeconds;
  final String? sourceSessionId;
  final String? sourceMessageId;
  final String? sourceOperation;
  final String? mistakeId;
  final String? parentQuestionId;
  final DateTime createdAt;
  final bool deleted;
  const PracticeQuestion({
    required this.id,
    required this.kind,
    required this.stem,
    required this.subject,
    required this.explanation,
    required this.hint,
    required this.origin,
    required this.verification,
    required this.absoluteTolerance,
    required this.relativeTolerance,
    required this.caseSensitive,
    this.timeLimitSeconds,
    this.sourceSessionId,
    this.sourceMessageId,
    this.sourceOperation,
    this.mistakeId,
    this.parentQuestionId,
    required this.createdAt,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['stem'] = Variable<String>(stem);
    map['subject'] = Variable<String>(subject);
    map['explanation'] = Variable<String>(explanation);
    map['hint'] = Variable<String>(hint);
    map['origin'] = Variable<String>(origin);
    map['verification'] = Variable<String>(verification);
    map['absolute_tolerance'] = Variable<double>(absoluteTolerance);
    map['relative_tolerance'] = Variable<double>(relativeTolerance);
    map['case_sensitive'] = Variable<bool>(caseSensitive);
    if (!nullToAbsent || timeLimitSeconds != null) {
      map['time_limit_seconds'] = Variable<int>(timeLimitSeconds);
    }
    if (!nullToAbsent || sourceSessionId != null) {
      map['source_session_id'] = Variable<String>(sourceSessionId);
    }
    if (!nullToAbsent || sourceMessageId != null) {
      map['source_message_id'] = Variable<String>(sourceMessageId);
    }
    if (!nullToAbsent || sourceOperation != null) {
      map['source_operation'] = Variable<String>(sourceOperation);
    }
    if (!nullToAbsent || mistakeId != null) {
      map['mistake_id'] = Variable<String>(mistakeId);
    }
    if (!nullToAbsent || parentQuestionId != null) {
      map['parent_question_id'] = Variable<String>(parentQuestionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  PracticeQuestionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeQuestionsCompanion(
      id: Value(id),
      kind: Value(kind),
      stem: Value(stem),
      subject: Value(subject),
      explanation: Value(explanation),
      hint: Value(hint),
      origin: Value(origin),
      verification: Value(verification),
      absoluteTolerance: Value(absoluteTolerance),
      relativeTolerance: Value(relativeTolerance),
      caseSensitive: Value(caseSensitive),
      timeLimitSeconds: timeLimitSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(timeLimitSeconds),
      sourceSessionId: sourceSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSessionId),
      sourceMessageId: sourceMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceMessageId),
      sourceOperation: sourceOperation == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceOperation),
      mistakeId: mistakeId == null && nullToAbsent
          ? const Value.absent()
          : Value(mistakeId),
      parentQuestionId: parentQuestionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentQuestionId),
      createdAt: Value(createdAt),
      deleted: Value(deleted),
    );
  }

  factory PracticeQuestion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeQuestion(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      stem: serializer.fromJson<String>(json['stem']),
      subject: serializer.fromJson<String>(json['subject']),
      explanation: serializer.fromJson<String>(json['explanation']),
      hint: serializer.fromJson<String>(json['hint']),
      origin: serializer.fromJson<String>(json['origin']),
      verification: serializer.fromJson<String>(json['verification']),
      absoluteTolerance: serializer.fromJson<double>(json['absoluteTolerance']),
      relativeTolerance: serializer.fromJson<double>(json['relativeTolerance']),
      caseSensitive: serializer.fromJson<bool>(json['caseSensitive']),
      timeLimitSeconds: serializer.fromJson<int?>(json['timeLimitSeconds']),
      sourceSessionId: serializer.fromJson<String?>(json['sourceSessionId']),
      sourceMessageId: serializer.fromJson<String?>(json['sourceMessageId']),
      sourceOperation: serializer.fromJson<String?>(json['sourceOperation']),
      mistakeId: serializer.fromJson<String?>(json['mistakeId']),
      parentQuestionId: serializer.fromJson<String?>(json['parentQuestionId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'stem': serializer.toJson<String>(stem),
      'subject': serializer.toJson<String>(subject),
      'explanation': serializer.toJson<String>(explanation),
      'hint': serializer.toJson<String>(hint),
      'origin': serializer.toJson<String>(origin),
      'verification': serializer.toJson<String>(verification),
      'absoluteTolerance': serializer.toJson<double>(absoluteTolerance),
      'relativeTolerance': serializer.toJson<double>(relativeTolerance),
      'caseSensitive': serializer.toJson<bool>(caseSensitive),
      'timeLimitSeconds': serializer.toJson<int?>(timeLimitSeconds),
      'sourceSessionId': serializer.toJson<String?>(sourceSessionId),
      'sourceMessageId': serializer.toJson<String?>(sourceMessageId),
      'sourceOperation': serializer.toJson<String?>(sourceOperation),
      'mistakeId': serializer.toJson<String?>(mistakeId),
      'parentQuestionId': serializer.toJson<String?>(parentQuestionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  PracticeQuestion copyWith({
    String? id,
    String? kind,
    String? stem,
    String? subject,
    String? explanation,
    String? hint,
    String? origin,
    String? verification,
    double? absoluteTolerance,
    double? relativeTolerance,
    bool? caseSensitive,
    Value<int?> timeLimitSeconds = const Value.absent(),
    Value<String?> sourceSessionId = const Value.absent(),
    Value<String?> sourceMessageId = const Value.absent(),
    Value<String?> sourceOperation = const Value.absent(),
    Value<String?> mistakeId = const Value.absent(),
    Value<String?> parentQuestionId = const Value.absent(),
    DateTime? createdAt,
    bool? deleted,
  }) => PracticeQuestion(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    stem: stem ?? this.stem,
    subject: subject ?? this.subject,
    explanation: explanation ?? this.explanation,
    hint: hint ?? this.hint,
    origin: origin ?? this.origin,
    verification: verification ?? this.verification,
    absoluteTolerance: absoluteTolerance ?? this.absoluteTolerance,
    relativeTolerance: relativeTolerance ?? this.relativeTolerance,
    caseSensitive: caseSensitive ?? this.caseSensitive,
    timeLimitSeconds: timeLimitSeconds.present
        ? timeLimitSeconds.value
        : this.timeLimitSeconds,
    sourceSessionId: sourceSessionId.present
        ? sourceSessionId.value
        : this.sourceSessionId,
    sourceMessageId: sourceMessageId.present
        ? sourceMessageId.value
        : this.sourceMessageId,
    sourceOperation: sourceOperation.present
        ? sourceOperation.value
        : this.sourceOperation,
    mistakeId: mistakeId.present ? mistakeId.value : this.mistakeId,
    parentQuestionId: parentQuestionId.present
        ? parentQuestionId.value
        : this.parentQuestionId,
    createdAt: createdAt ?? this.createdAt,
    deleted: deleted ?? this.deleted,
  );
  PracticeQuestion copyWithCompanion(PracticeQuestionsCompanion data) {
    return PracticeQuestion(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      stem: data.stem.present ? data.stem.value : this.stem,
      subject: data.subject.present ? data.subject.value : this.subject,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      hint: data.hint.present ? data.hint.value : this.hint,
      origin: data.origin.present ? data.origin.value : this.origin,
      verification: data.verification.present
          ? data.verification.value
          : this.verification,
      absoluteTolerance: data.absoluteTolerance.present
          ? data.absoluteTolerance.value
          : this.absoluteTolerance,
      relativeTolerance: data.relativeTolerance.present
          ? data.relativeTolerance.value
          : this.relativeTolerance,
      caseSensitive: data.caseSensitive.present
          ? data.caseSensitive.value
          : this.caseSensitive,
      timeLimitSeconds: data.timeLimitSeconds.present
          ? data.timeLimitSeconds.value
          : this.timeLimitSeconds,
      sourceSessionId: data.sourceSessionId.present
          ? data.sourceSessionId.value
          : this.sourceSessionId,
      sourceMessageId: data.sourceMessageId.present
          ? data.sourceMessageId.value
          : this.sourceMessageId,
      sourceOperation: data.sourceOperation.present
          ? data.sourceOperation.value
          : this.sourceOperation,
      mistakeId: data.mistakeId.present ? data.mistakeId.value : this.mistakeId,
      parentQuestionId: data.parentQuestionId.present
          ? data.parentQuestionId.value
          : this.parentQuestionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeQuestion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('stem: $stem, ')
          ..write('subject: $subject, ')
          ..write('explanation: $explanation, ')
          ..write('hint: $hint, ')
          ..write('origin: $origin, ')
          ..write('verification: $verification, ')
          ..write('absoluteTolerance: $absoluteTolerance, ')
          ..write('relativeTolerance: $relativeTolerance, ')
          ..write('caseSensitive: $caseSensitive, ')
          ..write('timeLimitSeconds: $timeLimitSeconds, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('sourceOperation: $sourceOperation, ')
          ..write('mistakeId: $mistakeId, ')
          ..write('parentQuestionId: $parentQuestionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    stem,
    subject,
    explanation,
    hint,
    origin,
    verification,
    absoluteTolerance,
    relativeTolerance,
    caseSensitive,
    timeLimitSeconds,
    sourceSessionId,
    sourceMessageId,
    sourceOperation,
    mistakeId,
    parentQuestionId,
    createdAt,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeQuestion &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.stem == this.stem &&
          other.subject == this.subject &&
          other.explanation == this.explanation &&
          other.hint == this.hint &&
          other.origin == this.origin &&
          other.verification == this.verification &&
          other.absoluteTolerance == this.absoluteTolerance &&
          other.relativeTolerance == this.relativeTolerance &&
          other.caseSensitive == this.caseSensitive &&
          other.timeLimitSeconds == this.timeLimitSeconds &&
          other.sourceSessionId == this.sourceSessionId &&
          other.sourceMessageId == this.sourceMessageId &&
          other.sourceOperation == this.sourceOperation &&
          other.mistakeId == this.mistakeId &&
          other.parentQuestionId == this.parentQuestionId &&
          other.createdAt == this.createdAt &&
          other.deleted == this.deleted);
}

class PracticeQuestionsCompanion extends UpdateCompanion<PracticeQuestion> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> stem;
  final Value<String> subject;
  final Value<String> explanation;
  final Value<String> hint;
  final Value<String> origin;
  final Value<String> verification;
  final Value<double> absoluteTolerance;
  final Value<double> relativeTolerance;
  final Value<bool> caseSensitive;
  final Value<int?> timeLimitSeconds;
  final Value<String?> sourceSessionId;
  final Value<String?> sourceMessageId;
  final Value<String?> sourceOperation;
  final Value<String?> mistakeId;
  final Value<String?> parentQuestionId;
  final Value<DateTime> createdAt;
  final Value<bool> deleted;
  final Value<int> rowid;
  const PracticeQuestionsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.stem = const Value.absent(),
    this.subject = const Value.absent(),
    this.explanation = const Value.absent(),
    this.hint = const Value.absent(),
    this.origin = const Value.absent(),
    this.verification = const Value.absent(),
    this.absoluteTolerance = const Value.absent(),
    this.relativeTolerance = const Value.absent(),
    this.caseSensitive = const Value.absent(),
    this.timeLimitSeconds = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.sourceOperation = const Value.absent(),
    this.mistakeId = const Value.absent(),
    this.parentQuestionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeQuestionsCompanion.insert({
    required String id,
    required String kind,
    required String stem,
    required String subject,
    this.explanation = const Value.absent(),
    this.hint = const Value.absent(),
    required String origin,
    this.verification = const Value.absent(),
    this.absoluteTolerance = const Value.absent(),
    this.relativeTolerance = const Value.absent(),
    this.caseSensitive = const Value.absent(),
    this.timeLimitSeconds = const Value.absent(),
    this.sourceSessionId = const Value.absent(),
    this.sourceMessageId = const Value.absent(),
    this.sourceOperation = const Value.absent(),
    this.mistakeId = const Value.absent(),
    this.parentQuestionId = const Value.absent(),
    required DateTime createdAt,
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       stem = Value(stem),
       subject = Value(subject),
       origin = Value(origin),
       createdAt = Value(createdAt);
  static Insertable<PracticeQuestion> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? stem,
    Expression<String>? subject,
    Expression<String>? explanation,
    Expression<String>? hint,
    Expression<String>? origin,
    Expression<String>? verification,
    Expression<double>? absoluteTolerance,
    Expression<double>? relativeTolerance,
    Expression<bool>? caseSensitive,
    Expression<int>? timeLimitSeconds,
    Expression<String>? sourceSessionId,
    Expression<String>? sourceMessageId,
    Expression<String>? sourceOperation,
    Expression<String>? mistakeId,
    Expression<String>? parentQuestionId,
    Expression<DateTime>? createdAt,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (stem != null) 'stem': stem,
      if (subject != null) 'subject': subject,
      if (explanation != null) 'explanation': explanation,
      if (hint != null) 'hint': hint,
      if (origin != null) 'origin': origin,
      if (verification != null) 'verification': verification,
      if (absoluteTolerance != null) 'absolute_tolerance': absoluteTolerance,
      if (relativeTolerance != null) 'relative_tolerance': relativeTolerance,
      if (caseSensitive != null) 'case_sensitive': caseSensitive,
      if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
      if (sourceSessionId != null) 'source_session_id': sourceSessionId,
      if (sourceMessageId != null) 'source_message_id': sourceMessageId,
      if (sourceOperation != null) 'source_operation': sourceOperation,
      if (mistakeId != null) 'mistake_id': mistakeId,
      if (parentQuestionId != null) 'parent_question_id': parentQuestionId,
      if (createdAt != null) 'created_at': createdAt,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeQuestionsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? stem,
    Value<String>? subject,
    Value<String>? explanation,
    Value<String>? hint,
    Value<String>? origin,
    Value<String>? verification,
    Value<double>? absoluteTolerance,
    Value<double>? relativeTolerance,
    Value<bool>? caseSensitive,
    Value<int?>? timeLimitSeconds,
    Value<String?>? sourceSessionId,
    Value<String?>? sourceMessageId,
    Value<String?>? sourceOperation,
    Value<String?>? mistakeId,
    Value<String?>? parentQuestionId,
    Value<DateTime>? createdAt,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return PracticeQuestionsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      stem: stem ?? this.stem,
      subject: subject ?? this.subject,
      explanation: explanation ?? this.explanation,
      hint: hint ?? this.hint,
      origin: origin ?? this.origin,
      verification: verification ?? this.verification,
      absoluteTolerance: absoluteTolerance ?? this.absoluteTolerance,
      relativeTolerance: relativeTolerance ?? this.relativeTolerance,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      sourceOperation: sourceOperation ?? this.sourceOperation,
      mistakeId: mistakeId ?? this.mistakeId,
      parentQuestionId: parentQuestionId ?? this.parentQuestionId,
      createdAt: createdAt ?? this.createdAt,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (stem.present) {
      map['stem'] = Variable<String>(stem.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (hint.present) {
      map['hint'] = Variable<String>(hint.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (verification.present) {
      map['verification'] = Variable<String>(verification.value);
    }
    if (absoluteTolerance.present) {
      map['absolute_tolerance'] = Variable<double>(absoluteTolerance.value);
    }
    if (relativeTolerance.present) {
      map['relative_tolerance'] = Variable<double>(relativeTolerance.value);
    }
    if (caseSensitive.present) {
      map['case_sensitive'] = Variable<bool>(caseSensitive.value);
    }
    if (timeLimitSeconds.present) {
      map['time_limit_seconds'] = Variable<int>(timeLimitSeconds.value);
    }
    if (sourceSessionId.present) {
      map['source_session_id'] = Variable<String>(sourceSessionId.value);
    }
    if (sourceMessageId.present) {
      map['source_message_id'] = Variable<String>(sourceMessageId.value);
    }
    if (sourceOperation.present) {
      map['source_operation'] = Variable<String>(sourceOperation.value);
    }
    if (mistakeId.present) {
      map['mistake_id'] = Variable<String>(mistakeId.value);
    }
    if (parentQuestionId.present) {
      map['parent_question_id'] = Variable<String>(parentQuestionId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeQuestionsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('stem: $stem, ')
          ..write('subject: $subject, ')
          ..write('explanation: $explanation, ')
          ..write('hint: $hint, ')
          ..write('origin: $origin, ')
          ..write('verification: $verification, ')
          ..write('absoluteTolerance: $absoluteTolerance, ')
          ..write('relativeTolerance: $relativeTolerance, ')
          ..write('caseSensitive: $caseSensitive, ')
          ..write('timeLimitSeconds: $timeLimitSeconds, ')
          ..write('sourceSessionId: $sourceSessionId, ')
          ..write('sourceMessageId: $sourceMessageId, ')
          ..write('sourceOperation: $sourceOperation, ')
          ..write('mistakeId: $mistakeId, ')
          ..write('parentQuestionId: $parentQuestionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeOptionsTable extends PracticeOptions
    with TableInfo<$PracticeOptionsTable, PracticeOption> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeOptionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _optionIdMeta = const VerificationMeta(
    'optionId',
  );
  @override
  late final GeneratedColumn<String> optionId = GeneratedColumn<String>(
    'option_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    questionId,
    optionId,
    content,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_options';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeOption> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('option_id')) {
      context.handle(
        _optionIdMeta,
        optionId.isAcceptableOrUnknown(data['option_id']!, _optionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_optionIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId, optionId};
  @override
  PracticeOption map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeOption(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      optionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}option_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PracticeOptionsTable createAlias(String alias) {
    return $PracticeOptionsTable(attachedDatabase, alias);
  }
}

class PracticeOption extends DataClass implements Insertable<PracticeOption> {
  final String questionId;
  final String optionId;
  final String content;
  final int position;
  const PracticeOption({
    required this.questionId,
    required this.optionId,
    required this.content,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['option_id'] = Variable<String>(optionId);
    map['content'] = Variable<String>(content);
    map['position'] = Variable<int>(position);
    return map;
  }

  PracticeOptionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeOptionsCompanion(
      questionId: Value(questionId),
      optionId: Value(optionId),
      content: Value(content),
      position: Value(position),
    );
  }

  factory PracticeOption.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeOption(
      questionId: serializer.fromJson<String>(json['questionId']),
      optionId: serializer.fromJson<String>(json['optionId']),
      content: serializer.fromJson<String>(json['content']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'optionId': serializer.toJson<String>(optionId),
      'content': serializer.toJson<String>(content),
      'position': serializer.toJson<int>(position),
    };
  }

  PracticeOption copyWith({
    String? questionId,
    String? optionId,
    String? content,
    int? position,
  }) => PracticeOption(
    questionId: questionId ?? this.questionId,
    optionId: optionId ?? this.optionId,
    content: content ?? this.content,
    position: position ?? this.position,
  );
  PracticeOption copyWithCompanion(PracticeOptionsCompanion data) {
    return PracticeOption(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      optionId: data.optionId.present ? data.optionId.value : this.optionId,
      content: data.content.present ? data.content.value : this.content,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeOption(')
          ..write('questionId: $questionId, ')
          ..write('optionId: $optionId, ')
          ..write('content: $content, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, optionId, content, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeOption &&
          other.questionId == this.questionId &&
          other.optionId == this.optionId &&
          other.content == this.content &&
          other.position == this.position);
}

class PracticeOptionsCompanion extends UpdateCompanion<PracticeOption> {
  final Value<String> questionId;
  final Value<String> optionId;
  final Value<String> content;
  final Value<int> position;
  final Value<int> rowid;
  const PracticeOptionsCompanion({
    this.questionId = const Value.absent(),
    this.optionId = const Value.absent(),
    this.content = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeOptionsCompanion.insert({
    required String questionId,
    required String optionId,
    required String content,
    required int position,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       optionId = Value(optionId),
       content = Value(content),
       position = Value(position);
  static Insertable<PracticeOption> custom({
    Expression<String>? questionId,
    Expression<String>? optionId,
    Expression<String>? content,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (optionId != null) 'option_id': optionId,
      if (content != null) 'content': content,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeOptionsCompanion copyWith({
    Value<String>? questionId,
    Value<String>? optionId,
    Value<String>? content,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PracticeOptionsCompanion(
      questionId: questionId ?? this.questionId,
      optionId: optionId ?? this.optionId,
      content: content ?? this.content,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (optionId.present) {
      map['option_id'] = Variable<String>(optionId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeOptionsCompanion(')
          ..write('questionId: $questionId, ')
          ..write('optionId: $optionId, ')
          ..write('content: $content, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeAnswerKeysTable extends PracticeAnswerKeys
    with TableInfo<$PracticeAnswerKeysTable, PracticeAnswerKey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeAnswerKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, position, answer];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_answer_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeAnswerKey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId, position, answer};
  @override
  PracticeAnswerKey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeAnswerKey(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
    );
  }

  @override
  $PracticeAnswerKeysTable createAlias(String alias) {
    return $PracticeAnswerKeysTable(attachedDatabase, alias);
  }
}

class PracticeAnswerKey extends DataClass
    implements Insertable<PracticeAnswerKey> {
  final String questionId;
  final int position;
  final String answer;
  const PracticeAnswerKey({
    required this.questionId,
    required this.position,
    required this.answer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['position'] = Variable<int>(position);
    map['answer'] = Variable<String>(answer);
    return map;
  }

  PracticeAnswerKeysCompanion toCompanion(bool nullToAbsent) {
    return PracticeAnswerKeysCompanion(
      questionId: Value(questionId),
      position: Value(position),
      answer: Value(answer),
    );
  }

  factory PracticeAnswerKey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeAnswerKey(
      questionId: serializer.fromJson<String>(json['questionId']),
      position: serializer.fromJson<int>(json['position']),
      answer: serializer.fromJson<String>(json['answer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'position': serializer.toJson<int>(position),
      'answer': serializer.toJson<String>(answer),
    };
  }

  PracticeAnswerKey copyWith({
    String? questionId,
    int? position,
    String? answer,
  }) => PracticeAnswerKey(
    questionId: questionId ?? this.questionId,
    position: position ?? this.position,
    answer: answer ?? this.answer,
  );
  PracticeAnswerKey copyWithCompanion(PracticeAnswerKeysCompanion data) {
    return PracticeAnswerKey(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      position: data.position.present ? data.position.value : this.position,
      answer: data.answer.present ? data.answer.value : this.answer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeAnswerKey(')
          ..write('questionId: $questionId, ')
          ..write('position: $position, ')
          ..write('answer: $answer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, position, answer);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeAnswerKey &&
          other.questionId == this.questionId &&
          other.position == this.position &&
          other.answer == this.answer);
}

class PracticeAnswerKeysCompanion extends UpdateCompanion<PracticeAnswerKey> {
  final Value<String> questionId;
  final Value<int> position;
  final Value<String> answer;
  final Value<int> rowid;
  const PracticeAnswerKeysCompanion({
    this.questionId = const Value.absent(),
    this.position = const Value.absent(),
    this.answer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeAnswerKeysCompanion.insert({
    required String questionId,
    required int position,
    required String answer,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       position = Value(position),
       answer = Value(answer);
  static Insertable<PracticeAnswerKey> custom({
    Expression<String>? questionId,
    Expression<int>? position,
    Expression<String>? answer,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (position != null) 'position': position,
      if (answer != null) 'answer': answer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeAnswerKeysCompanion copyWith({
    Value<String>? questionId,
    Value<int>? position,
    Value<String>? answer,
    Value<int>? rowid,
  }) {
    return PracticeAnswerKeysCompanion(
      questionId: questionId ?? this.questionId,
      position: position ?? this.position,
      answer: answer ?? this.answer,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeAnswerKeysCompanion(')
          ..write('questionId: $questionId, ')
          ..write('position: $position, ')
          ..write('answer: $answer, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeQuestionTopicsTable extends PracticeQuestionTopics
    with TableInfo<$PracticeQuestionTopicsTable, PracticeQuestionTopic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeQuestionTopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES learning_topics (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, topicId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_question_topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeQuestionTopic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId, topicId};
  @override
  PracticeQuestionTopic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeQuestionTopic(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      )!,
    );
  }

  @override
  $PracticeQuestionTopicsTable createAlias(String alias) {
    return $PracticeQuestionTopicsTable(attachedDatabase, alias);
  }
}

class PracticeQuestionTopic extends DataClass
    implements Insertable<PracticeQuestionTopic> {
  final String questionId;
  final String topicId;
  const PracticeQuestionTopic({
    required this.questionId,
    required this.topicId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['topic_id'] = Variable<String>(topicId);
    return map;
  }

  PracticeQuestionTopicsCompanion toCompanion(bool nullToAbsent) {
    return PracticeQuestionTopicsCompanion(
      questionId: Value(questionId),
      topicId: Value(topicId),
    );
  }

  factory PracticeQuestionTopic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeQuestionTopic(
      questionId: serializer.fromJson<String>(json['questionId']),
      topicId: serializer.fromJson<String>(json['topicId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'topicId': serializer.toJson<String>(topicId),
    };
  }

  PracticeQuestionTopic copyWith({String? questionId, String? topicId}) =>
      PracticeQuestionTopic(
        questionId: questionId ?? this.questionId,
        topicId: topicId ?? this.topicId,
      );
  PracticeQuestionTopic copyWithCompanion(
    PracticeQuestionTopicsCompanion data,
  ) {
    return PracticeQuestionTopic(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeQuestionTopic(')
          ..write('questionId: $questionId, ')
          ..write('topicId: $topicId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, topicId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeQuestionTopic &&
          other.questionId == this.questionId &&
          other.topicId == this.topicId);
}

class PracticeQuestionTopicsCompanion
    extends UpdateCompanion<PracticeQuestionTopic> {
  final Value<String> questionId;
  final Value<String> topicId;
  final Value<int> rowid;
  const PracticeQuestionTopicsCompanion({
    this.questionId = const Value.absent(),
    this.topicId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeQuestionTopicsCompanion.insert({
    required String questionId,
    required String topicId,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       topicId = Value(topicId);
  static Insertable<PracticeQuestionTopic> custom({
    Expression<String>? questionId,
    Expression<String>? topicId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (topicId != null) 'topic_id': topicId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeQuestionTopicsCompanion copyWith({
    Value<String>? questionId,
    Value<String>? topicId,
    Value<int>? rowid,
  }) {
    return PracticeQuestionTopicsCompanion(
      questionId: questionId ?? this.questionId,
      topicId: topicId ?? this.topicId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeQuestionTopicsCompanion(')
          ..write('questionId: $questionId, ')
          ..write('topicId: $topicId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeQuestionKnowledgeTable extends PracticeQuestionKnowledge
    with
        TableInfo<
          $PracticeQuestionKnowledgeTable,
          PracticeQuestionKnowledgeData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeQuestionKnowledgeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _knowledgeIdMeta = const VerificationMeta(
    'knowledgeId',
  );
  @override
  late final GeneratedColumn<String> knowledgeId = GeneratedColumn<String>(
    'knowledge_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES knowledge_items (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, knowledgeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_question_knowledge';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeQuestionKnowledgeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('knowledge_id')) {
      context.handle(
        _knowledgeIdMeta,
        knowledgeId.isAcceptableOrUnknown(
          data['knowledge_id']!,
          _knowledgeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_knowledgeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId, knowledgeId};
  @override
  PracticeQuestionKnowledgeData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeQuestionKnowledgeData(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      knowledgeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}knowledge_id'],
      )!,
    );
  }

  @override
  $PracticeQuestionKnowledgeTable createAlias(String alias) {
    return $PracticeQuestionKnowledgeTable(attachedDatabase, alias);
  }
}

class PracticeQuestionKnowledgeData extends DataClass
    implements Insertable<PracticeQuestionKnowledgeData> {
  final String questionId;
  final String knowledgeId;
  const PracticeQuestionKnowledgeData({
    required this.questionId,
    required this.knowledgeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['knowledge_id'] = Variable<String>(knowledgeId);
    return map;
  }

  PracticeQuestionKnowledgeCompanion toCompanion(bool nullToAbsent) {
    return PracticeQuestionKnowledgeCompanion(
      questionId: Value(questionId),
      knowledgeId: Value(knowledgeId),
    );
  }

  factory PracticeQuestionKnowledgeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeQuestionKnowledgeData(
      questionId: serializer.fromJson<String>(json['questionId']),
      knowledgeId: serializer.fromJson<String>(json['knowledgeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'knowledgeId': serializer.toJson<String>(knowledgeId),
    };
  }

  PracticeQuestionKnowledgeData copyWith({
    String? questionId,
    String? knowledgeId,
  }) => PracticeQuestionKnowledgeData(
    questionId: questionId ?? this.questionId,
    knowledgeId: knowledgeId ?? this.knowledgeId,
  );
  PracticeQuestionKnowledgeData copyWithCompanion(
    PracticeQuestionKnowledgeCompanion data,
  ) {
    return PracticeQuestionKnowledgeData(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      knowledgeId: data.knowledgeId.present
          ? data.knowledgeId.value
          : this.knowledgeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeQuestionKnowledgeData(')
          ..write('questionId: $questionId, ')
          ..write('knowledgeId: $knowledgeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, knowledgeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeQuestionKnowledgeData &&
          other.questionId == this.questionId &&
          other.knowledgeId == this.knowledgeId);
}

class PracticeQuestionKnowledgeCompanion
    extends UpdateCompanion<PracticeQuestionKnowledgeData> {
  final Value<String> questionId;
  final Value<String> knowledgeId;
  final Value<int> rowid;
  const PracticeQuestionKnowledgeCompanion({
    this.questionId = const Value.absent(),
    this.knowledgeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeQuestionKnowledgeCompanion.insert({
    required String questionId,
    required String knowledgeId,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       knowledgeId = Value(knowledgeId);
  static Insertable<PracticeQuestionKnowledgeData> custom({
    Expression<String>? questionId,
    Expression<String>? knowledgeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeQuestionKnowledgeCompanion copyWith({
    Value<String>? questionId,
    Value<String>? knowledgeId,
    Value<int>? rowid,
  }) {
    return PracticeQuestionKnowledgeCompanion(
      questionId: questionId ?? this.questionId,
      knowledgeId: knowledgeId ?? this.knowledgeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (knowledgeId.present) {
      map['knowledge_id'] = Variable<String>(knowledgeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeQuestionKnowledgeCompanion(')
          ..write('questionId: $questionId, ')
          ..write('knowledgeId: $knowledgeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeAttemptsTable extends PracticeAttempts
    with TableInfo<$PracticeAttemptsTable, PracticeAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _hintUsedMeta = const VerificationMeta(
    'hintUsed',
  );
  @override
  late final GeneratedColumn<bool> hintUsed = GeneratedColumn<bool>(
    'hint_used',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hint_used" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<bool> correct = GeneratedColumn<bool>(
    'correct',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("correct" IN (0, 1))',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradingBasisMeta = const VerificationMeta(
    'gradingBasis',
  );
  @override
  late final GeneratedColumn<String> gradingBasis = GeneratedColumn<String>(
    'grading_basis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<DateTime> submittedAt = GeneratedColumn<DateTime>(
    'submitted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elapsedMillisecondsMeta =
      const VerificationMeta('elapsedMilliseconds');
  @override
  late final GeneratedColumn<int> elapsedMilliseconds = GeneratedColumn<int>(
    'elapsed_milliseconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    status,
    hintUsed,
    correct,
    score,
    gradingBasis,
    startedAt,
    submittedAt,
    elapsedMilliseconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('hint_used')) {
      context.handle(
        _hintUsedMeta,
        hintUsed.isAcceptableOrUnknown(data['hint_used']!, _hintUsedMeta),
      );
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('grading_basis')) {
      context.handle(
        _gradingBasisMeta,
        gradingBasis.isAcceptableOrUnknown(
          data['grading_basis']!,
          _gradingBasisMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_milliseconds')) {
      context.handle(
        _elapsedMillisecondsMeta,
        elapsedMilliseconds.isAcceptableOrUnknown(
          data['elapsed_milliseconds']!,
          _elapsedMillisecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeAttempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      hintUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hint_used'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}correct'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      gradingBasis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grading_basis'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}submitted_at'],
      ),
      elapsedMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_milliseconds'],
      ),
    );
  }

  @override
  $PracticeAttemptsTable createAlias(String alias) {
    return $PracticeAttemptsTable(attachedDatabase, alias);
  }
}

class PracticeAttempt extends DataClass implements Insertable<PracticeAttempt> {
  final String id;
  final String questionId;
  final String status;
  final bool hintUsed;
  final bool? correct;
  final double? score;
  final String? gradingBasis;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final int? elapsedMilliseconds;
  const PracticeAttempt({
    required this.id,
    required this.questionId,
    required this.status,
    required this.hintUsed,
    this.correct,
    this.score,
    this.gradingBasis,
    required this.startedAt,
    this.submittedAt,
    this.elapsedMilliseconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['question_id'] = Variable<String>(questionId);
    map['status'] = Variable<String>(status);
    map['hint_used'] = Variable<bool>(hintUsed);
    if (!nullToAbsent || correct != null) {
      map['correct'] = Variable<bool>(correct);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || gradingBasis != null) {
      map['grading_basis'] = Variable<String>(gradingBasis);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || submittedAt != null) {
      map['submitted_at'] = Variable<DateTime>(submittedAt);
    }
    if (!nullToAbsent || elapsedMilliseconds != null) {
      map['elapsed_milliseconds'] = Variable<int>(elapsedMilliseconds);
    }
    return map;
  }

  PracticeAttemptsCompanion toCompanion(bool nullToAbsent) {
    return PracticeAttemptsCompanion(
      id: Value(id),
      questionId: Value(questionId),
      status: Value(status),
      hintUsed: Value(hintUsed),
      correct: correct == null && nullToAbsent
          ? const Value.absent()
          : Value(correct),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      gradingBasis: gradingBasis == null && nullToAbsent
          ? const Value.absent()
          : Value(gradingBasis),
      startedAt: Value(startedAt),
      submittedAt: submittedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(submittedAt),
      elapsedMilliseconds: elapsedMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(elapsedMilliseconds),
    );
  }

  factory PracticeAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeAttempt(
      id: serializer.fromJson<String>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      status: serializer.fromJson<String>(json['status']),
      hintUsed: serializer.fromJson<bool>(json['hintUsed']),
      correct: serializer.fromJson<bool?>(json['correct']),
      score: serializer.fromJson<double?>(json['score']),
      gradingBasis: serializer.fromJson<String?>(json['gradingBasis']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      submittedAt: serializer.fromJson<DateTime?>(json['submittedAt']),
      elapsedMilliseconds: serializer.fromJson<int?>(
        json['elapsedMilliseconds'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'questionId': serializer.toJson<String>(questionId),
      'status': serializer.toJson<String>(status),
      'hintUsed': serializer.toJson<bool>(hintUsed),
      'correct': serializer.toJson<bool?>(correct),
      'score': serializer.toJson<double?>(score),
      'gradingBasis': serializer.toJson<String?>(gradingBasis),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'submittedAt': serializer.toJson<DateTime?>(submittedAt),
      'elapsedMilliseconds': serializer.toJson<int?>(elapsedMilliseconds),
    };
  }

  PracticeAttempt copyWith({
    String? id,
    String? questionId,
    String? status,
    bool? hintUsed,
    Value<bool?> correct = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<String?> gradingBasis = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> submittedAt = const Value.absent(),
    Value<int?> elapsedMilliseconds = const Value.absent(),
  }) => PracticeAttempt(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    status: status ?? this.status,
    hintUsed: hintUsed ?? this.hintUsed,
    correct: correct.present ? correct.value : this.correct,
    score: score.present ? score.value : this.score,
    gradingBasis: gradingBasis.present ? gradingBasis.value : this.gradingBasis,
    startedAt: startedAt ?? this.startedAt,
    submittedAt: submittedAt.present ? submittedAt.value : this.submittedAt,
    elapsedMilliseconds: elapsedMilliseconds.present
        ? elapsedMilliseconds.value
        : this.elapsedMilliseconds,
  );
  PracticeAttempt copyWithCompanion(PracticeAttemptsCompanion data) {
    return PracticeAttempt(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      status: data.status.present ? data.status.value : this.status,
      hintUsed: data.hintUsed.present ? data.hintUsed.value : this.hintUsed,
      correct: data.correct.present ? data.correct.value : this.correct,
      score: data.score.present ? data.score.value : this.score,
      gradingBasis: data.gradingBasis.present
          ? data.gradingBasis.value
          : this.gradingBasis,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
      elapsedMilliseconds: data.elapsedMilliseconds.present
          ? data.elapsedMilliseconds.value
          : this.elapsedMilliseconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeAttempt(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('status: $status, ')
          ..write('hintUsed: $hintUsed, ')
          ..write('correct: $correct, ')
          ..write('score: $score, ')
          ..write('gradingBasis: $gradingBasis, ')
          ..write('startedAt: $startedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('elapsedMilliseconds: $elapsedMilliseconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questionId,
    status,
    hintUsed,
    correct,
    score,
    gradingBasis,
    startedAt,
    submittedAt,
    elapsedMilliseconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeAttempt &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.status == this.status &&
          other.hintUsed == this.hintUsed &&
          other.correct == this.correct &&
          other.score == this.score &&
          other.gradingBasis == this.gradingBasis &&
          other.startedAt == this.startedAt &&
          other.submittedAt == this.submittedAt &&
          other.elapsedMilliseconds == this.elapsedMilliseconds);
}

class PracticeAttemptsCompanion extends UpdateCompanion<PracticeAttempt> {
  final Value<String> id;
  final Value<String> questionId;
  final Value<String> status;
  final Value<bool> hintUsed;
  final Value<bool?> correct;
  final Value<double?> score;
  final Value<String?> gradingBasis;
  final Value<DateTime> startedAt;
  final Value<DateTime?> submittedAt;
  final Value<int?> elapsedMilliseconds;
  final Value<int> rowid;
  const PracticeAttemptsCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.status = const Value.absent(),
    this.hintUsed = const Value.absent(),
    this.correct = const Value.absent(),
    this.score = const Value.absent(),
    this.gradingBasis = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.elapsedMilliseconds = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeAttemptsCompanion.insert({
    required String id,
    required String questionId,
    this.status = const Value.absent(),
    this.hintUsed = const Value.absent(),
    this.correct = const Value.absent(),
    this.score = const Value.absent(),
    this.gradingBasis = const Value.absent(),
    required DateTime startedAt,
    this.submittedAt = const Value.absent(),
    this.elapsedMilliseconds = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       questionId = Value(questionId),
       startedAt = Value(startedAt);
  static Insertable<PracticeAttempt> custom({
    Expression<String>? id,
    Expression<String>? questionId,
    Expression<String>? status,
    Expression<bool>? hintUsed,
    Expression<bool>? correct,
    Expression<double>? score,
    Expression<String>? gradingBasis,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? submittedAt,
    Expression<int>? elapsedMilliseconds,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (status != null) 'status': status,
      if (hintUsed != null) 'hint_used': hintUsed,
      if (correct != null) 'correct': correct,
      if (score != null) 'score': score,
      if (gradingBasis != null) 'grading_basis': gradingBasis,
      if (startedAt != null) 'started_at': startedAt,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (elapsedMilliseconds != null)
        'elapsed_milliseconds': elapsedMilliseconds,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeAttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? questionId,
    Value<String>? status,
    Value<bool>? hintUsed,
    Value<bool?>? correct,
    Value<double?>? score,
    Value<String?>? gradingBasis,
    Value<DateTime>? startedAt,
    Value<DateTime?>? submittedAt,
    Value<int?>? elapsedMilliseconds,
    Value<int>? rowid,
  }) {
    return PracticeAttemptsCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      status: status ?? this.status,
      hintUsed: hintUsed ?? this.hintUsed,
      correct: correct ?? this.correct,
      score: score ?? this.score,
      gradingBasis: gradingBasis ?? this.gradingBasis,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      elapsedMilliseconds: elapsedMilliseconds ?? this.elapsedMilliseconds,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (hintUsed.present) {
      map['hint_used'] = Variable<bool>(hintUsed.value);
    }
    if (correct.present) {
      map['correct'] = Variable<bool>(correct.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (gradingBasis.present) {
      map['grading_basis'] = Variable<String>(gradingBasis.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<DateTime>(submittedAt.value);
    }
    if (elapsedMilliseconds.present) {
      map['elapsed_milliseconds'] = Variable<int>(elapsedMilliseconds.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('status: $status, ')
          ..write('hintUsed: $hintUsed, ')
          ..write('correct: $correct, ')
          ..write('score: $score, ')
          ..write('gradingBasis: $gradingBasis, ')
          ..write('startedAt: $startedAt, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('elapsedMilliseconds: $elapsedMilliseconds, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeResponsesTable extends PracticeResponses
    with TableInfo<$PracticeResponsesTable, PracticeResponse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeResponsesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_attempts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [attemptId, position, answer];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_responses';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeResponse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {attemptId, position};
  @override
  PracticeResponse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeResponse(
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
    );
  }

  @override
  $PracticeResponsesTable createAlias(String alias) {
    return $PracticeResponsesTable(attachedDatabase, alias);
  }
}

class PracticeResponse extends DataClass
    implements Insertable<PracticeResponse> {
  final String attemptId;
  final int position;
  final String answer;
  const PracticeResponse({
    required this.attemptId,
    required this.position,
    required this.answer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['attempt_id'] = Variable<String>(attemptId);
    map['position'] = Variable<int>(position);
    map['answer'] = Variable<String>(answer);
    return map;
  }

  PracticeResponsesCompanion toCompanion(bool nullToAbsent) {
    return PracticeResponsesCompanion(
      attemptId: Value(attemptId),
      position: Value(position),
      answer: Value(answer),
    );
  }

  factory PracticeResponse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeResponse(
      attemptId: serializer.fromJson<String>(json['attemptId']),
      position: serializer.fromJson<int>(json['position']),
      answer: serializer.fromJson<String>(json['answer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'attemptId': serializer.toJson<String>(attemptId),
      'position': serializer.toJson<int>(position),
      'answer': serializer.toJson<String>(answer),
    };
  }

  PracticeResponse copyWith({
    String? attemptId,
    int? position,
    String? answer,
  }) => PracticeResponse(
    attemptId: attemptId ?? this.attemptId,
    position: position ?? this.position,
    answer: answer ?? this.answer,
  );
  PracticeResponse copyWithCompanion(PracticeResponsesCompanion data) {
    return PracticeResponse(
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      position: data.position.present ? data.position.value : this.position,
      answer: data.answer.present ? data.answer.value : this.answer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeResponse(')
          ..write('attemptId: $attemptId, ')
          ..write('position: $position, ')
          ..write('answer: $answer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(attemptId, position, answer);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeResponse &&
          other.attemptId == this.attemptId &&
          other.position == this.position &&
          other.answer == this.answer);
}

class PracticeResponsesCompanion extends UpdateCompanion<PracticeResponse> {
  final Value<String> attemptId;
  final Value<int> position;
  final Value<String> answer;
  final Value<int> rowid;
  const PracticeResponsesCompanion({
    this.attemptId = const Value.absent(),
    this.position = const Value.absent(),
    this.answer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeResponsesCompanion.insert({
    required String attemptId,
    required int position,
    required String answer,
    this.rowid = const Value.absent(),
  }) : attemptId = Value(attemptId),
       position = Value(position),
       answer = Value(answer);
  static Insertable<PracticeResponse> custom({
    Expression<String>? attemptId,
    Expression<int>? position,
    Expression<String>? answer,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (attemptId != null) 'attempt_id': attemptId,
      if (position != null) 'position': position,
      if (answer != null) 'answer': answer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeResponsesCompanion copyWith({
    Value<String>? attemptId,
    Value<int>? position,
    Value<String>? answer,
    Value<int>? rowid,
  }) {
    return PracticeResponsesCompanion(
      attemptId: attemptId ?? this.attemptId,
      position: position ?? this.position,
      answer: answer ?? this.answer,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeResponsesCompanion(')
          ..write('attemptId: $attemptId, ')
          ..write('position: $position, ')
          ..write('answer: $answer, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeImagesTable extends PracticeImages
    with TableInfo<$PracticeImagesTable, PracticeImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    relativePath,
    mime,
    byteLength,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    } else if (isInserting) {
      context.missing(_byteLengthMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      )!,
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      )!,
    );
  }

  @override
  $PracticeImagesTable createAlias(String alias) {
    return $PracticeImagesTable(attachedDatabase, alias);
  }
}

class PracticeImage extends DataClass implements Insertable<PracticeImage> {
  final String id;
  final String questionId;
  final String relativePath;
  final String mime;
  final int byteLength;
  const PracticeImage({
    required this.id,
    required this.questionId,
    required this.relativePath,
    required this.mime,
    required this.byteLength,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['question_id'] = Variable<String>(questionId);
    map['relative_path'] = Variable<String>(relativePath);
    map['mime'] = Variable<String>(mime);
    map['byte_length'] = Variable<int>(byteLength);
    return map;
  }

  PracticeImagesCompanion toCompanion(bool nullToAbsent) {
    return PracticeImagesCompanion(
      id: Value(id),
      questionId: Value(questionId),
      relativePath: Value(relativePath),
      mime: Value(mime),
      byteLength: Value(byteLength),
    );
  }

  factory PracticeImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeImage(
      id: serializer.fromJson<String>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mime: serializer.fromJson<String>(json['mime']),
      byteLength: serializer.fromJson<int>(json['byteLength']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'questionId': serializer.toJson<String>(questionId),
      'relativePath': serializer.toJson<String>(relativePath),
      'mime': serializer.toJson<String>(mime),
      'byteLength': serializer.toJson<int>(byteLength),
    };
  }

  PracticeImage copyWith({
    String? id,
    String? questionId,
    String? relativePath,
    String? mime,
    int? byteLength,
  }) => PracticeImage(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    relativePath: relativePath ?? this.relativePath,
    mime: mime ?? this.mime,
    byteLength: byteLength ?? this.byteLength,
  );
  PracticeImage copyWithCompanion(PracticeImagesCompanion data) {
    return PracticeImage(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mime: data.mime.present ? data.mime.value : this.mime,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeImage(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, questionId, relativePath, mime, byteLength);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeImage &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.relativePath == this.relativePath &&
          other.mime == this.mime &&
          other.byteLength == this.byteLength);
}

class PracticeImagesCompanion extends UpdateCompanion<PracticeImage> {
  final Value<String> id;
  final Value<String> questionId;
  final Value<String> relativePath;
  final Value<String> mime;
  final Value<int> byteLength;
  final Value<int> rowid;
  const PracticeImagesCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeImagesCompanion.insert({
    required String id,
    required String questionId,
    required String relativePath,
    required String mime,
    required int byteLength,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       questionId = Value(questionId),
       relativePath = Value(relativePath),
       mime = Value(mime),
       byteLength = Value(byteLength);
  static Insertable<PracticeImage> custom({
    Expression<String>? id,
    Expression<String>? questionId,
    Expression<String>? relativePath,
    Expression<String>? mime,
    Expression<int>? byteLength,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (relativePath != null) 'relative_path': relativePath,
      if (mime != null) 'mime': mime,
      if (byteLength != null) 'byte_length': byteLength,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeImagesCompanion copyWith({
    Value<String>? id,
    Value<String>? questionId,
    Value<String>? relativePath,
    Value<String>? mime,
    Value<int>? byteLength,
    Value<int>? rowid,
  }) {
    return PracticeImagesCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      relativePath: relativePath ?? this.relativePath,
      mime: mime ?? this.mime,
      byteLength: byteLength ?? this.byteLength,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeImagesCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewSchedulesTable extends ReviewSchedules
    with TableInfo<$ReviewSchedulesTable, ReviewSchedule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewSchedulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta(
    'repetitions',
  );
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _easeMeta = const VerificationMeta('ease');
  @override
  late final GeneratedColumn<double> ease = GeneratedColumn<double>(
    'ease',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _lapsesMeta = const VerificationMeta('lapses');
  @override
  late final GeneratedColumn<int> lapses = GeneratedColumn<int>(
    'lapses',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    questionId,
    dueAt,
    repetitions,
    intervalDays,
    ease,
    lapses,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_schedules';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewSchedule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(
          data['repetitions']!,
          _repetitionsMeta,
        ),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('ease')) {
      context.handle(
        _easeMeta,
        ease.isAcceptableOrUnknown(data['ease']!, _easeMeta),
      );
    }
    if (data.containsKey('lapses')) {
      context.handle(
        _lapsesMeta,
        lapses.isAcceptableOrUnknown(data['lapses']!, _lapsesMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewSchedule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewSchedule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      ease: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease'],
      )!,
      lapses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapses'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReviewSchedulesTable createAlias(String alias) {
    return $ReviewSchedulesTable(attachedDatabase, alias);
  }
}

class ReviewSchedule extends DataClass implements Insertable<ReviewSchedule> {
  final String id;
  final String questionId;
  final DateTime dueAt;
  final int repetitions;
  final int intervalDays;
  final double ease;
  final int lapses;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ReviewSchedule({
    required this.id,
    required this.questionId,
    required this.dueAt,
    required this.repetitions,
    required this.intervalDays,
    required this.ease,
    required this.lapses,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['question_id'] = Variable<String>(questionId);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['repetitions'] = Variable<int>(repetitions);
    map['interval_days'] = Variable<int>(intervalDays);
    map['ease'] = Variable<double>(ease);
    map['lapses'] = Variable<int>(lapses);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReviewSchedulesCompanion toCompanion(bool nullToAbsent) {
    return ReviewSchedulesCompanion(
      id: Value(id),
      questionId: Value(questionId),
      dueAt: Value(dueAt),
      repetitions: Value(repetitions),
      intervalDays: Value(intervalDays),
      ease: Value(ease),
      lapses: Value(lapses),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReviewSchedule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewSchedule(
      id: serializer.fromJson<String>(json['id']),
      questionId: serializer.fromJson<String>(json['questionId']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      ease: serializer.fromJson<double>(json['ease']),
      lapses: serializer.fromJson<int>(json['lapses']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'questionId': serializer.toJson<String>(questionId),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'repetitions': serializer.toJson<int>(repetitions),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'ease': serializer.toJson<double>(ease),
      'lapses': serializer.toJson<int>(lapses),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReviewSchedule copyWith({
    String? id,
    String? questionId,
    DateTime? dueAt,
    int? repetitions,
    int? intervalDays,
    double? ease,
    int? lapses,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ReviewSchedule(
    id: id ?? this.id,
    questionId: questionId ?? this.questionId,
    dueAt: dueAt ?? this.dueAt,
    repetitions: repetitions ?? this.repetitions,
    intervalDays: intervalDays ?? this.intervalDays,
    ease: ease ?? this.ease,
    lapses: lapses ?? this.lapses,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReviewSchedule copyWithCompanion(ReviewSchedulesCompanion data) {
    return ReviewSchedule(
      id: data.id.present ? data.id.value : this.id,
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      repetitions: data.repetitions.present
          ? data.repetitions.value
          : this.repetitions,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      ease: data.ease.present ? data.ease.value : this.ease,
      lapses: data.lapses.present ? data.lapses.value : this.lapses,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewSchedule(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('dueAt: $dueAt, ')
          ..write('repetitions: $repetitions, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('ease: $ease, ')
          ..write('lapses: $lapses, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    questionId,
    dueAt,
    repetitions,
    intervalDays,
    ease,
    lapses,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewSchedule &&
          other.id == this.id &&
          other.questionId == this.questionId &&
          other.dueAt == this.dueAt &&
          other.repetitions == this.repetitions &&
          other.intervalDays == this.intervalDays &&
          other.ease == this.ease &&
          other.lapses == this.lapses &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ReviewSchedulesCompanion extends UpdateCompanion<ReviewSchedule> {
  final Value<String> id;
  final Value<String> questionId;
  final Value<DateTime> dueAt;
  final Value<int> repetitions;
  final Value<int> intervalDays;
  final Value<double> ease;
  final Value<int> lapses;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReviewSchedulesCompanion({
    this.id = const Value.absent(),
    this.questionId = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.ease = const Value.absent(),
    this.lapses = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewSchedulesCompanion.insert({
    required String id,
    required String questionId,
    required DateTime dueAt,
    this.repetitions = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.ease = const Value.absent(),
    this.lapses = const Value.absent(),
    this.enabled = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       questionId = Value(questionId),
       dueAt = Value(dueAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ReviewSchedule> custom({
    Expression<String>? id,
    Expression<String>? questionId,
    Expression<DateTime>? dueAt,
    Expression<int>? repetitions,
    Expression<int>? intervalDays,
    Expression<double>? ease,
    Expression<int>? lapses,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (questionId != null) 'question_id': questionId,
      if (dueAt != null) 'due_at': dueAt,
      if (repetitions != null) 'repetitions': repetitions,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (ease != null) 'ease': ease,
      if (lapses != null) 'lapses': lapses,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewSchedulesCompanion copyWith({
    Value<String>? id,
    Value<String>? questionId,
    Value<DateTime>? dueAt,
    Value<int>? repetitions,
    Value<int>? intervalDays,
    Value<double>? ease,
    Value<int>? lapses,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReviewSchedulesCompanion(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      dueAt: dueAt ?? this.dueAt,
      repetitions: repetitions ?? this.repetitions,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      lapses: lapses ?? this.lapses,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (ease.present) {
      map['ease'] = Variable<double>(ease.value);
    }
    if (lapses.present) {
      map['lapses'] = Variable<int>(lapses.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewSchedulesCompanion(')
          ..write('id: $id, ')
          ..write('questionId: $questionId, ')
          ..write('dueAt: $dueAt, ')
          ..write('repetitions: $repetitions, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('ease: $ease, ')
          ..write('lapses: $lapses, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewRecordsTable extends ReviewRecords
    with TableInfo<$ReviewRecordsTable, ReviewRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduleIdMeta = const VerificationMeta(
    'scheduleId',
  );
  @override
  late final GeneratedColumn<String> scheduleId = GeneratedColumn<String>(
    'schedule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES review_schedules (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_attempts (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
    'event',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousDueAtMeta = const VerificationMeta(
    'previousDueAt',
  );
  @override
  late final GeneratedColumn<DateTime> previousDueAt =
      GeneratedColumn<DateTime>(
        'previous_due_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _nextDueAtMeta = const VerificationMeta(
    'nextDueAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextDueAt = GeneratedColumn<DateTime>(
    'next_due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _independentMeta = const VerificationMeta(
    'independent',
  );
  @override
  late final GeneratedColumn<bool> independent = GeneratedColumn<bool>(
    'independent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("independent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduleId,
    attemptId,
    event,
    previousDueAt,
    nextDueAt,
    quality,
    independent,
    reason,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('schedule_id')) {
      context.handle(
        _scheduleIdMeta,
        scheduleId.isAcceptableOrUnknown(data['schedule_id']!, _scheduleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    }
    if (data.containsKey('event')) {
      context.handle(
        _eventMeta,
        event.isAcceptableOrUnknown(data['event']!, _eventMeta),
      );
    } else if (isInserting) {
      context.missing(_eventMeta);
    }
    if (data.containsKey('previous_due_at')) {
      context.handle(
        _previousDueAtMeta,
        previousDueAt.isAcceptableOrUnknown(
          data['previous_due_at']!,
          _previousDueAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previousDueAtMeta);
    }
    if (data.containsKey('next_due_at')) {
      context.handle(
        _nextDueAtMeta,
        nextDueAt.isAcceptableOrUnknown(data['next_due_at']!, _nextDueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDueAtMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('independent')) {
      context.handle(
        _independentMeta,
        independent.isAcceptableOrUnknown(
          data['independent']!,
          _independentMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {scheduleId, attemptId},
  ];
  @override
  ReviewRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      scheduleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      ),
      event: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event'],
      )!,
      previousDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}previous_due_at'],
      )!,
      nextDueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_due_at'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      ),
      independent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}independent'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $ReviewRecordsTable createAlias(String alias) {
    return $ReviewRecordsTable(attachedDatabase, alias);
  }
}

class ReviewRecord extends DataClass implements Insertable<ReviewRecord> {
  final String id;
  final String scheduleId;
  final String? attemptId;
  final String event;
  final DateTime previousDueAt;
  final DateTime nextDueAt;
  final int? quality;
  final bool independent;
  final String reason;
  final DateTime recordedAt;
  const ReviewRecord({
    required this.id,
    required this.scheduleId,
    this.attemptId,
    required this.event,
    required this.previousDueAt,
    required this.nextDueAt,
    this.quality,
    required this.independent,
    required this.reason,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['schedule_id'] = Variable<String>(scheduleId);
    if (!nullToAbsent || attemptId != null) {
      map['attempt_id'] = Variable<String>(attemptId);
    }
    map['event'] = Variable<String>(event);
    map['previous_due_at'] = Variable<DateTime>(previousDueAt);
    map['next_due_at'] = Variable<DateTime>(nextDueAt);
    if (!nullToAbsent || quality != null) {
      map['quality'] = Variable<int>(quality);
    }
    map['independent'] = Variable<bool>(independent);
    map['reason'] = Variable<String>(reason);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  ReviewRecordsCompanion toCompanion(bool nullToAbsent) {
    return ReviewRecordsCompanion(
      id: Value(id),
      scheduleId: Value(scheduleId),
      attemptId: attemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(attemptId),
      event: Value(event),
      previousDueAt: Value(previousDueAt),
      nextDueAt: Value(nextDueAt),
      quality: quality == null && nullToAbsent
          ? const Value.absent()
          : Value(quality),
      independent: Value(independent),
      reason: Value(reason),
      recordedAt: Value(recordedAt),
    );
  }

  factory ReviewRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewRecord(
      id: serializer.fromJson<String>(json['id']),
      scheduleId: serializer.fromJson<String>(json['scheduleId']),
      attemptId: serializer.fromJson<String?>(json['attemptId']),
      event: serializer.fromJson<String>(json['event']),
      previousDueAt: serializer.fromJson<DateTime>(json['previousDueAt']),
      nextDueAt: serializer.fromJson<DateTime>(json['nextDueAt']),
      quality: serializer.fromJson<int?>(json['quality']),
      independent: serializer.fromJson<bool>(json['independent']),
      reason: serializer.fromJson<String>(json['reason']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scheduleId': serializer.toJson<String>(scheduleId),
      'attemptId': serializer.toJson<String?>(attemptId),
      'event': serializer.toJson<String>(event),
      'previousDueAt': serializer.toJson<DateTime>(previousDueAt),
      'nextDueAt': serializer.toJson<DateTime>(nextDueAt),
      'quality': serializer.toJson<int?>(quality),
      'independent': serializer.toJson<bool>(independent),
      'reason': serializer.toJson<String>(reason),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  ReviewRecord copyWith({
    String? id,
    String? scheduleId,
    Value<String?> attemptId = const Value.absent(),
    String? event,
    DateTime? previousDueAt,
    DateTime? nextDueAt,
    Value<int?> quality = const Value.absent(),
    bool? independent,
    String? reason,
    DateTime? recordedAt,
  }) => ReviewRecord(
    id: id ?? this.id,
    scheduleId: scheduleId ?? this.scheduleId,
    attemptId: attemptId.present ? attemptId.value : this.attemptId,
    event: event ?? this.event,
    previousDueAt: previousDueAt ?? this.previousDueAt,
    nextDueAt: nextDueAt ?? this.nextDueAt,
    quality: quality.present ? quality.value : this.quality,
    independent: independent ?? this.independent,
    reason: reason ?? this.reason,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  ReviewRecord copyWithCompanion(ReviewRecordsCompanion data) {
    return ReviewRecord(
      id: data.id.present ? data.id.value : this.id,
      scheduleId: data.scheduleId.present
          ? data.scheduleId.value
          : this.scheduleId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      event: data.event.present ? data.event.value : this.event,
      previousDueAt: data.previousDueAt.present
          ? data.previousDueAt.value
          : this.previousDueAt,
      nextDueAt: data.nextDueAt.present ? data.nextDueAt.value : this.nextDueAt,
      quality: data.quality.present ? data.quality.value : this.quality,
      independent: data.independent.present
          ? data.independent.value
          : this.independent,
      reason: data.reason.present ? data.reason.value : this.reason,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewRecord(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('attemptId: $attemptId, ')
          ..write('event: $event, ')
          ..write('previousDueAt: $previousDueAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('quality: $quality, ')
          ..write('independent: $independent, ')
          ..write('reason: $reason, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scheduleId,
    attemptId,
    event,
    previousDueAt,
    nextDueAt,
    quality,
    independent,
    reason,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewRecord &&
          other.id == this.id &&
          other.scheduleId == this.scheduleId &&
          other.attemptId == this.attemptId &&
          other.event == this.event &&
          other.previousDueAt == this.previousDueAt &&
          other.nextDueAt == this.nextDueAt &&
          other.quality == this.quality &&
          other.independent == this.independent &&
          other.reason == this.reason &&
          other.recordedAt == this.recordedAt);
}

class ReviewRecordsCompanion extends UpdateCompanion<ReviewRecord> {
  final Value<String> id;
  final Value<String> scheduleId;
  final Value<String?> attemptId;
  final Value<String> event;
  final Value<DateTime> previousDueAt;
  final Value<DateTime> nextDueAt;
  final Value<int?> quality;
  final Value<bool> independent;
  final Value<String> reason;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const ReviewRecordsCompanion({
    this.id = const Value.absent(),
    this.scheduleId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.event = const Value.absent(),
    this.previousDueAt = const Value.absent(),
    this.nextDueAt = const Value.absent(),
    this.quality = const Value.absent(),
    this.independent = const Value.absent(),
    this.reason = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewRecordsCompanion.insert({
    required String id,
    required String scheduleId,
    this.attemptId = const Value.absent(),
    required String event,
    required DateTime previousDueAt,
    required DateTime nextDueAt,
    this.quality = const Value.absent(),
    this.independent = const Value.absent(),
    required String reason,
    required DateTime recordedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       scheduleId = Value(scheduleId),
       event = Value(event),
       previousDueAt = Value(previousDueAt),
       nextDueAt = Value(nextDueAt),
       reason = Value(reason),
       recordedAt = Value(recordedAt);
  static Insertable<ReviewRecord> custom({
    Expression<String>? id,
    Expression<String>? scheduleId,
    Expression<String>? attemptId,
    Expression<String>? event,
    Expression<DateTime>? previousDueAt,
    Expression<DateTime>? nextDueAt,
    Expression<int>? quality,
    Expression<bool>? independent,
    Expression<String>? reason,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduleId != null) 'schedule_id': scheduleId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (event != null) 'event': event,
      if (previousDueAt != null) 'previous_due_at': previousDueAt,
      if (nextDueAt != null) 'next_due_at': nextDueAt,
      if (quality != null) 'quality': quality,
      if (independent != null) 'independent': independent,
      if (reason != null) 'reason': reason,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? scheduleId,
    Value<String?>? attemptId,
    Value<String>? event,
    Value<DateTime>? previousDueAt,
    Value<DateTime>? nextDueAt,
    Value<int?>? quality,
    Value<bool>? independent,
    Value<String>? reason,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return ReviewRecordsCompanion(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      attemptId: attemptId ?? this.attemptId,
      event: event ?? this.event,
      previousDueAt: previousDueAt ?? this.previousDueAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      quality: quality ?? this.quality,
      independent: independent ?? this.independent,
      reason: reason ?? this.reason,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scheduleId.present) {
      map['schedule_id'] = Variable<String>(scheduleId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (previousDueAt.present) {
      map['previous_due_at'] = Variable<DateTime>(previousDueAt.value);
    }
    if (nextDueAt.present) {
      map['next_due_at'] = Variable<DateTime>(nextDueAt.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (independent.present) {
      map['independent'] = Variable<bool>(independent.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewRecordsCompanion(')
          ..write('id: $id, ')
          ..write('scheduleId: $scheduleId, ')
          ..write('attemptId: $attemptId, ')
          ..write('event: $event, ')
          ..write('previousDueAt: $previousDueAt, ')
          ..write('nextDueAt: $nextDueAt, ')
          ..write('quality: $quality, ')
          ..write('independent: $independent, ')
          ..write('reason: $reason, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeChatLinksTable extends PracticeChatLinks
    with TableInfo<$PracticeChatLinksTable, PracticeChatLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeChatLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_questions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES chat_messages (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, messageId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_chat_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeChatLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId, messageId};
  @override
  PracticeChatLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeChatLink(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
    );
  }

  @override
  $PracticeChatLinksTable createAlias(String alias) {
    return $PracticeChatLinksTable(attachedDatabase, alias);
  }
}

class PracticeChatLink extends DataClass
    implements Insertable<PracticeChatLink> {
  final String questionId;
  final String messageId;
  const PracticeChatLink({required this.questionId, required this.messageId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['message_id'] = Variable<String>(messageId);
    return map;
  }

  PracticeChatLinksCompanion toCompanion(bool nullToAbsent) {
    return PracticeChatLinksCompanion(
      questionId: Value(questionId),
      messageId: Value(messageId),
    );
  }

  factory PracticeChatLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeChatLink(
      questionId: serializer.fromJson<String>(json['questionId']),
      messageId: serializer.fromJson<String>(json['messageId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'messageId': serializer.toJson<String>(messageId),
    };
  }

  PracticeChatLink copyWith({String? questionId, String? messageId}) =>
      PracticeChatLink(
        questionId: questionId ?? this.questionId,
        messageId: messageId ?? this.messageId,
      );
  PracticeChatLink copyWithCompanion(PracticeChatLinksCompanion data) {
    return PracticeChatLink(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeChatLink(')
          ..write('questionId: $questionId, ')
          ..write('messageId: $messageId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, messageId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeChatLink &&
          other.questionId == this.questionId &&
          other.messageId == this.messageId);
}

class PracticeChatLinksCompanion extends UpdateCompanion<PracticeChatLink> {
  final Value<String> questionId;
  final Value<String> messageId;
  final Value<int> rowid;
  const PracticeChatLinksCompanion({
    this.questionId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeChatLinksCompanion.insert({
    required String questionId,
    required String messageId,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       messageId = Value(messageId);
  static Insertable<PracticeChatLink> custom({
    Expression<String>? questionId,
    Expression<String>? messageId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (messageId != null) 'message_id': messageId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeChatLinksCompanion copyWith({
    Value<String>? questionId,
    Value<String>? messageId,
    Value<int>? rowid,
  }) {
    return PracticeChatLinksCompanion(
      questionId: questionId ?? this.questionId,
      messageId: messageId ?? this.messageId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeChatLinksCompanion(')
          ..write('questionId: $questionId, ')
          ..write('messageId: $messageId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $ChatSessionsTable chatSessions = $ChatSessionsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $ProviderConfigsTable providerConfigs = $ProviderConfigsTable(
    this,
  );
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $KnowledgeItemsTable knowledgeItems = $KnowledgeItemsTable(this);
  late final $KnowledgeRevisionsTable knowledgeRevisions =
      $KnowledgeRevisionsTable(this);
  late final $MistakesTable mistakes = $MistakesTable(this);
  late final $KnowledgeTagsTable knowledgeTags = $KnowledgeTagsTable(this);
  late final $MistakeTagsTable mistakeTags = $MistakeTagsTable(this);
  late final $KnowledgeRelationsTable knowledgeRelations =
      $KnowledgeRelationsTable(this);
  late final $MistakeKnowledgeLinksTable mistakeKnowledgeLinks =
      $MistakeKnowledgeLinksTable(this);
  late final $StudyAttachmentsTable studyAttachments = $StudyAttachmentsTable(
    this,
  );
  late final $AiToolOperationsTable aiToolOperations = $AiToolOperationsTable(
    this,
  );
  late final $StudyChatLinksTable studyChatLinks = $StudyChatLinksTable(this);
  late final $LearningTopicsTable learningTopics = $LearningTopicsTable(this);
  late final $PracticeQuestionsTable practiceQuestions =
      $PracticeQuestionsTable(this);
  late final $PracticeOptionsTable practiceOptions = $PracticeOptionsTable(
    this,
  );
  late final $PracticeAnswerKeysTable practiceAnswerKeys =
      $PracticeAnswerKeysTable(this);
  late final $PracticeQuestionTopicsTable practiceQuestionTopics =
      $PracticeQuestionTopicsTable(this);
  late final $PracticeQuestionKnowledgeTable practiceQuestionKnowledge =
      $PracticeQuestionKnowledgeTable(this);
  late final $PracticeAttemptsTable practiceAttempts = $PracticeAttemptsTable(
    this,
  );
  late final $PracticeResponsesTable practiceResponses =
      $PracticeResponsesTable(this);
  late final $PracticeImagesTable practiceImages = $PracticeImagesTable(this);
  late final $ReviewSchedulesTable reviewSchedules = $ReviewSchedulesTable(
    this,
  );
  late final $ReviewRecordsTable reviewRecords = $ReviewRecordsTable(this);
  late final $PracticeChatLinksTable practiceChatLinks =
      $PracticeChatLinksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chatSessions,
    chatMessages,
    attachments,
    providerConfigs,
    preferences,
    knowledgeItems,
    knowledgeRevisions,
    mistakes,
    knowledgeTags,
    mistakeTags,
    knowledgeRelations,
    mistakeKnowledgeLinks,
    studyAttachments,
    aiToolOperations,
    studyChatLinks,
    learningTopics,
    practiceQuestions,
    practiceOptions,
    practiceAnswerKeys,
    practiceQuestionTopics,
    practiceQuestionKnowledge,
    practiceAttempts,
    practiceResponses,
    practiceImages,
    reviewSchedules,
    reviewRecords,
    practiceChatLinks,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chat_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_revisions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mistakes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mistakes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mistakes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mistake_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_relations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('knowledge_relations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mistakes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mistake_knowledge_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('mistake_knowledge_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('study_attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mistakes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('study_attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('study_chat_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('study_chat_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mistakes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('study_chat_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_questions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_questions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'mistakes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_questions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_questions', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_options', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_answer_keys', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('practice_question_topics', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'learning_topics',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('practice_question_topics', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('practice_question_knowledge', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'knowledge_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('practice_question_knowledge', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_attempts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_responses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_images', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_schedules', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'review_schedules',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_records', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_attempts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('review_records', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_questions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_chat_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_chat_links', kind: UpdateKind.delete)],
    ),
  ]);
}
