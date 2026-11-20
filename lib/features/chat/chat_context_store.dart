import "dart:convert";

import "package:crypto/crypto.dart";
import "package:drift/drift.dart";
import "package:dio/dio.dart";

import "../../core/ai/ai_types.dart";
import "../../core/database/database.dart";

/// Current policy for replaying application-enriched history. A saved scope
/// records past authorization; it can never grant any new capabilities.
class ChatContextScope {
  ChatContextScope({
    required ProviderConfig config,
    required String mode,
    required String? subject,
    required bool studyAuthorized,
    required bool drawingEnabled,
    required String? writingScope,
  }) : _effort = config.thinking ? config.effort : null,
       _data = {
         // Do not store endpoint userinfo, query strings, or credentials.
         "transport":
             "${config.kind}:${sha256.convert(utf8.encode(config.baseUrl))}",
         "model": config.model,
         "thinking": config.thinking,
         "mode": mode,
         "subject": subject,
         "studyAuthorized": studyAuthorized,
         "drawingEnabled": drawingEnabled,
         "writingScope": writingScope,
       };

  final Map<String, Object?> _data;
  final String? _effort;
  bool get isExam => _data["mode"] == "exam";
  bool matches(Object? recorded) =>
      recorded is Map &&
      _data.entries.every((entry) => recorded[entry.key] == entry.value);
}

/// Local protocol-neutral transcript. Message IDs anchor input, model rounds
/// and compaction checkpoints in the same order as the visible conversation.
/// Only the Store interprets the event payloads; neither adapters nor widgets
/// read them. Images are references to first-class local attachments.
class ChatContextStore {
  ChatContextStore(this.db);
  final AppDatabase db;

  static const _checkpoint = -1;
  static const _input = 0;

  Future<ChatContextHistory> load(String sessionId) async {
    final events = db.chatContextEvents;
    final rows =
        await (db.select(events).join([
                innerJoin(
                  db.chatMessages,
                  db.chatMessages.id.equalsExp(events.messageId),
                ),
              ])
              ..where(db.chatMessages.sessionId.equals(sessionId))
              ..orderBy([OrderingTerm.asc(events.sequence)]))
            .get();
    return ChatContextHistory._([
      for (final row in rows) row.readTable(events),
    ]);
  }

  /// A run owns its rounds even when stopped. Only a complete assistant bubble
  /// can make them eligible for replay. No tool is invoked by reading history.
  Future<ChatContextRun?> start({
    required String sessionId,
    required String runId,
    required ChatMessage? input,
    required AiMessage? sentInput,
    required List<String> attachmentIds,
    required ChatContextScope scope,
    required List<ChatMessage> selected,
    required String? summaryThrough,
    required CancelToken cancel,
  }) async {
    final owner =
        await (db.select(
              db.chatMessages,
            )..where((m) => m.id.equals(runId) & m.sessionId.equals(sessionId)))
            .getSingleOrNull();
    if (owner == null) return null;
    final inputId = input?.sessionId == sessionId ? input?.id : null;
    final context = ChatContextRun._(this, runId, inputId, {
      "scope": scope._data,
      if (scope._effort != null) "effort": scope._effort,
      "first": selected.firstOrNull?.id,
      "last": selected.lastOrNull?.id,
      "summaryThrough": summaryThrough,
    }, scope.isExam);
    cancel.checkCancelled();
    if (inputId != null && sentInput != null) {
      await db
          .into(db.chatContextEvents)
          .insert(
            ChatContextEventsCompanion.insert(
              messageId: inputId,
              sequence: _input,
              payload: jsonEncode({
                "scope": scope._data,
                "text": sentInput.text,
                "attachments": attachmentIds,
              }),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    return context;
  }

  Future<void> checkpoint(String sessionId, String through, String summary) =>
      db.transaction(() async {
        final owner =
            await (db.select(db.chatMessages)..where(
                  (m) => m.id.equals(through) & m.sessionId.equals(sessionId),
                ))
                .getSingleOrNull();
        if (owner != null) {
          await db
              .into(db.chatContextEvents)
              .insertOnConflictUpdate(
                ChatContextEventsCompanion.insert(
                  messageId: through,
                  sequence: _checkpoint,
                  payload: jsonEncode({"summary": summary}),
                ),
              );
        }
        await db.setContextSummary(sessionId, summary, through);
      });

  Future<void> copyPrefix({
    required ChatContextHistory source,
    required Map<String, String> messages,
    required Map<String, String> attachments,
  }) async {
    for (final entry in source._events.entries) {
      final target = messages[entry.key];
      if (target == null) continue;
      for (final event in entry.value) {
        final inputId = messages[event.inputMessageId];
        if (event.inputMessageId != null && inputId == null) continue;
        var payload = event.payload;
        final value = _decode(payload);
        if (value == null) continue;
        if (event.sequence == _input) {
          final ids = _ids(value["attachments"]);
          value["attachments"] = [for (final id in ids) ?attachments[id]];
          payload = jsonEncode(value);
        } else if (event.sequence > _input) {
          if (value["run"] case final Map<String, dynamic> run) {
            for (final key in ["first", "last", "summaryThrough"]) {
              run[key] = messages[run[key]];
            }
            payload = jsonEncode(value);
          }
        }
        await db
            .into(db.chatContextEvents)
            .insert(
              event.copyWith(
                messageId: target,
                inputMessageId: Value(inputId),
                payload: payload,
              ),
            );
      }
    }
  }
}

class ChatContextHistory {
  ChatContextHistory._(List<ChatContextEvent> rows) {
    for (final row in rows) {
      _events.putIfAbsent(row.messageId, () => []).add(row);
    }
  }
  final _events = <String, List<ChatContextEvent>>{};

  (String, List<String>)? input(String id, ChatContextScope scope) {
    final row = _events[id]
        ?.where((e) => e.sequence == ChatContextStore._input)
        .firstOrNull;
    final value = _decode(row?.payload);
    if (value == null || !scope.matches(value["scope"])) return null;
    if (value["text"] case final String text) {
      return (text, _ids(value["attachments"]));
    }
    return null;
  }

  (String, String)? latestCheckpoint(Iterable<String> messageIds) {
    for (final id in messageIds.toList().reversed) {
      final row = _events[id]
          ?.where((e) => e.sequence == ChatContextStore._checkpoint)
          .firstOrNull;
      if (_decode(row?.payload)?["summary"] case final String summary) {
        return (id, summary);
      }
    }
    return null;
  }

  bool hasRounds(String id) =>
      _events[id]?.any((event) => event.sequence > ChatContextStore._input) ??
      false;

  /// Replay only whole batches under the current transport, mode and grants.
  /// Quiz arguments (including answer keys and solution figures) stay private.
  Map<String, List<AiMessage>> replies({
    required List<ChatMessage> history,
    required ChatContextScope scope,
    required Set<String> allowedTools,
  }) {
    final replies = <String, List<AiMessage>>{};
    final ids = <String>{};
    String? inputId;
    for (final message in history) {
      if (message.role == "user") {
        inputId = message.id;
        continue;
      }
      if (message.status != "complete") continue;
      final events = _events[message.id]?.where(
        (e) =>
            e.sequence > ChatContextStore._input && e.inputMessageId == inputId,
      );
      if (events == null || events.isEmpty) continue;
      final rounds = events.map((e) => _decode(e.payload)).toList();
      final run = rounds.first?["run"];
      if (run is! Map || scope.isExam || !scope.matches(run["scope"])) {
        continue;
      }
      final messages = <AiMessage>[];
      final turnIds = <String>{};
      var valid = true;
      for (final round in rounds) {
        if (round?["output"] case {
          "text": final String text,
          "calls": final List rawCalls,
        }) {
          final reasoning = (round!["output"] as Map)["reasoning"] as String?;
          if (rawCalls.isEmpty) {
            if (text.isNotEmpty) {
              messages.add(
                AiMessage.assistant(text, reasoningContent: reasoning),
              );
            }
            continue;
          }
          final results = round["results"];
          if (results is! List || results.length != rawCalls.length) {
            valid = false;
            break;
          }
          final calls = <ToolCall>[];
          final outputs = <AiMessage>[];
          for (var i = 0; i < rawCalls.length; i++) {
            final result = results[i];
            if (rawCalls[i]
                case {
                  "id": final String originalId,
                  "name": final String name,
                  "arguments": final String arguments,
                }
                when name != "create_quiz" &&
                    allowedTools.contains(name) &&
                    result is String) {
              var id = originalId;
              var suffix = 0;
              while (ids.contains(id) || turnIds.contains(id)) {
                id = "history_${message.id}_${turnIds.length}_${suffix++}";
              }
              turnIds.add(id);
              calls.add(ToolCall(id, name, arguments));
              outputs.add(AiMessage.tool(id, result));
            } else {
              valid = false;
              break;
            }
          }
          if (!valid) break;
          messages.add(
            AiMessage.assistant(
              text,
              calls: calls,
              reasoningContent: reasoning,
            ),
          );
          messages.addAll(outputs);
        } else {
          valid = false;
          break;
        }
      }
      if (!valid || messages.isEmpty) continue;
      ids.addAll(turnIds);
      replies[message.id] = messages;
    }
    return replies;
  }
}

class ChatContextRun {
  ChatContextRun._(
    this._store,
    this._id,
    this._inputId,
    this._metadata,
    this._isExam,
  );
  final ChatContextStore _store;
  final String _id;
  final String? _inputId;
  final Map<String, Object?> _metadata;
  final bool _isExam;
  var _sequence = 0;
  String? _instructions, _tools;
  late Map<String, Object?> _round;

  Future<void> request(AiRequest request) async {
    final tools = [
      for (final tool in request.tools)
        {
          "name": tool.name,
          "description": tool.description,
          "parameters": tool.parameters,
        },
    ];
    final toolState = jsonEncode(tools);
    _round = {
      if (_sequence == 0) "run": _metadata,
      if (_instructions != request.instructions)
        "instructions": request.instructions,
      if (_tools != toolState) "tools": tools,
      if (request.enableConversationTitle) "title": true,
      if (request.maxOutputTokens != null)
        "maxOutputTokens": request.maxOutputTokens,
    };
    _sequence++;
    _instructions = request.instructions;
    _tools = toolState;
    await _save();
  }

  Future<void> output(
    String text,
    String reasoning,
    List<ToolCall> calls,
  ) async {
    // Do not duplicate hidden answer keys, solution scenes, or exam output in
    // the transcript. Their owning practice records enforce access rules.
    if (_isExam || calls.any((call) => call.name == "create_quiz")) {
      _round["outputOmitted"] = true;
      await _save();
      return;
    }
    _round["output"] = {
      "text": text,
      if (reasoning.isNotEmpty) "reasoning": reasoning,
      "calls": [
        for (final call in calls)
          {"id": call.id, "name": call.name, "arguments": call.arguments},
      ],
    };
    await _save();
  }

  Future<void> results(Iterable<AiMessage> outputs) async {
    if (_round["outputOmitted"] == true) return;
    _round["results"] = [for (final output in outputs) output.text];
    await _save();
  }

  Future<void> _save() => _store.db
      .into(_store.db.chatContextEvents)
      .insertOnConflictUpdate(
        ChatContextEventsCompanion.insert(
          messageId: _id,
          sequence: _sequence,
          inputMessageId: Value(_inputId),
          payload: jsonEncode(_round),
        ),
      );
}

Map<String, dynamic>? _decode(String? payload) {
  if (payload == null) return null;
  try {
    final value = jsonDecode(payload);
    return value is Map<String, dynamic> ? value : null;
  } on FormatException {
    return null;
  }
}

List<String> _ids(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];
