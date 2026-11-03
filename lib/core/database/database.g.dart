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
  final String mime;
  final int byteLength;
  const Attachment({
    required this.id,
    required this.sessionId,
    this.messageId,
    required this.relativePath,
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
      'mime': serializer.toJson<String>(mime),
      'byteLength': serializer.toJson<int>(byteLength),
    };
  }

  Attachment copyWith({
    String? id,
    String? sessionId,
    Value<String?> messageId = const Value.absent(),
    String? relativePath,
    String? mime,
    int? byteLength,
  }) => Attachment(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    messageId: messageId.present ? messageId.value : this.messageId,
    relativePath: relativePath ?? this.relativePath,
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
          ..write('mime: $mime, ')
          ..write('byteLength: $byteLength')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionId, messageId, relativePath, mime, byteLength);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.messageId == this.messageId &&
          other.relativePath == this.relativePath &&
          other.mime == this.mime &&
          other.byteLength == this.byteLength);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> messageId;
  final Value<String> relativePath;
  final Value<String> mime;
  final Value<int> byteLength;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mime = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    required String sessionId,
    this.messageId = const Value.absent(),
    required String relativePath,
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
    Expression<String>? mime,
    Expression<int>? byteLength,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (messageId != null) 'message_id': messageId,
      if (relativePath != null) 'relative_path': relativePath,
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
    Value<String>? mime,
    Value<int>? byteLength,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      messageId: messageId ?? this.messageId,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
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
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('messageId: $messageId, ')
          ..write('relativePath: $relativePath, ')
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
  ]);
}
