import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/ai_types.dart';
import '../../core/database/database.dart';
import 'a2ui_catalog.dart';

class ChatA2uiStore {
  ChatA2uiStore(this.db);
  final AppDatabase db;

  Future<ChatA2uiSurface> create({
    required String sessionId,
    required String messageId,
    required String callId,
    required String express,
    required String? bodyAtInsertion,
    required CancelToken cancel,
  }) => db.transaction(() async {
    cancel.checkCancelled();
    final owner = await _owner(sessionId, messageId).getSingleOrNull();
    if (owner?.role != 'assistant' || owner?.status != 'generating') {
      throw const FormatException(
        'No active assistant message for this surface.',
      );
    }
    final siblings = _byMessage(sessionId, messageId);
    final existing =
        await (siblings..where((row) => row.toolCallId.equals(callId)))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.express != express ||
          (existing.autoOffset == null) != (bodyAtInsertion == null)) {
        throw const FormatException(
          'This tool call ID already has a different surface.',
        );
      }
      return existing;
    }
    final count = (await _byMessage(sessionId, messageId).get()).length;
    if (count >= 6) {
      throw const FormatException('At most six surfaces per message.');
    }
    final id = const Uuid().v4();
    final compiled = compileChatA2ui(express, id);
    cancel.checkCancelled();
    final surface = ChatA2uiSurfacesCompanion.insert(
      sessionId: sessionId,
      id: id,
      messageId: messageId,
      toolCallId: callId,
      protocol: chatA2uiProtocol,
      catalog: chatA2uiCatalogId,
      express: express,
      messagesJson: compiled,
      autoOffset: Value(bodyAtInsertion?.length),
      ordinal: count,
    );
    final created = await db.into(db.chatA2uiSurfaces).insertReturning(surface);
    if (bodyAtInsertion != null) {
      // Keep the prefix and its offset in one commit, even before the next
      // throttled streaming write or when the provider stops after the tool.
      await (db.update(db.chatMessages)..where((m) => m.id.equals(messageId)))
          .write(ChatMessagesCompanion(content: Value(bodyAtInsertion)));
    }
    return created;
  });

  SimpleSelectStatement<ChatMessages, ChatMessage> _owner(
    String sessionId,
    String id,
  ) =>
      db.select(db.chatMessages)
        ..where((m) => m.id.equals(id) & m.sessionId.equals(sessionId));

  SimpleSelectStatement<ChatA2uiSurfaces, ChatA2uiSurface> _byMessage(
    String sessionId,
    String messageId,
  ) => db.select(db.chatA2uiSurfaces)
    ..where(
      (row) =>
          row.sessionId.equals(sessionId) & row.messageId.equals(messageId),
    )
    ..orderBy([(row) => OrderingTerm.asc(row.ordinal)]);

  Stream<List<ChatA2uiSurface>> watchMessage(
    String sessionId,
    String messageId,
  ) => _byMessage(sessionId, messageId).watch().distinct(_sameSurfaces);

  Future<void> saveState(ChatA2uiSurface surface, String state) async {
    if (utf8.encode(state).length > chatA2uiMaxState) {
      throw const FormatException('Surface state exceeds its storage limit.');
    }
    await (db.update(db.chatA2uiSurfaces)..where(
          (r) =>
              r.sessionId.equals(surface.sessionId) & r.id.equals(surface.id),
        ))
        .write(ChatA2uiSurfacesCompanion(stateJson: Value(state)));
  }

  Future<void> recordAction(
    ChatA2uiSurface surface, {
    required String componentId,
    required String kind,
  }) async {
    if (!chatA2uiActions.contains(kind) || componentId.length > 64) {
      throw const FormatException('Unsupported surface action.');
    }
    // Keep an audit trail without duplicating form values or chat text.
    await db
        .into(db.chatA2uiActions)
        .insert(
          ChatA2uiActionsCompanion.insert(
            id: const Uuid().v4(),
            sessionId: surface.sessionId,
            surfaceId: surface.id,
            componentId: componentId,
            kind: kind,
            contextJson: '{}',
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> copyMessage({
    required String sourceSession,
    required String sourceMessage,
    required String targetSession,
    required String targetMessage,
  }) async {
    for (final surface in await _byMessage(
      sourceSession,
      sourceMessage,
    ).get()) {
      await db
          .into(db.chatA2uiSurfaces)
          .insert(
            surface.copyWith(
              sessionId: targetSession,
              messageId: targetMessage,
            ),
          );
      final actions =
          await (db.select(db.chatA2uiActions)..where(
                (a) =>
                    a.sessionId.equals(sourceSession) &
                    a.surfaceId.equals(surface.id),
              ))
              .get();
      await db.batch((batch) {
        batch.insertAll(db.chatA2uiActions, [
          for (final action in actions)
            action.copyWith(id: const Uuid().v4(), sessionId: targetSession),
        ]);
      });
    }
  }

  /// Used only for explicit follow-ups. Restrict disclosure to the nearest
  /// relevant assistant turn and send an outline, excluding form input.
  Future<String?> recentOutline(
    String sessionId,
    List<ChatMessage> history,
    String user,
  ) async {
    final explicitId = RegExp(r'^\[TiXun A2UI ([0-9a-f-]{36})\]')
        .firstMatch(user)?[1];
    if (explicitId != null) {
      final surface =
          await (db.select(db.chatA2uiSurfaces)..where(
                (row) =>
                    row.sessionId.equals(sessionId) & row.id.equals(explicitId),
              ))
              .getSingleOrNull();
      return surface == null ? null : _outline([surface]);
    }
    for (final message
        in history.reversed.where((m) => m.role == 'assistant').take(5)) {
      final surfaces = await _byMessage(sessionId, message.id).get();
      if (surfaces.isEmpty) continue;
      return _outline(surfaces.reversed.take(2));
    }
    return null;
  }

  String _outline(Iterable<ChatA2uiSurface> surfaces) => jsonEncode([
    for (final surface in surfaces)
      {
        'id': surface.id,
        'components': chatA2uiOutline(surface.messagesJson, surface.id),
      },
  ]);
}

bool _sameSurfaces(List<ChatA2uiSurface> a, List<ChatA2uiSurface> b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);
